#include <fcntl.h>
#include <stdio.h>
#include <stdbool.h>
#include <string.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>


const size_t BLK_SIZE = 128;
const size_t BUF_SIZE = 512;

static bool create_file_map;


static size_t blk_count(size_t size) {
    int count = size / BLK_SIZE;

    if (size % BLK_SIZE != 0) {
        ++count;
    }

    return count;
}

static int _lseek(int fd, off_t offset) {
    if (create_file_map) {
        printf("SEEK blk_count=%zu\n", blk_count(offset));
    }

    return lseek(fd, offset, SEEK_CUR);
}

static int _write(int fd, char* buf, size_t size) {
    if (create_file_map) {
        printf("WRITE blk_count=%zu\n", blk_count(size));
    }

    return write(fd, buf, size);
}

static bool is_blk_nul(char* buf, size_t size) {
    for (int i = 0; i < size; i++) {
        if (buf[i] != 0) {
            return false;
        }
    }

    return true;
}

/* create hole or write buf in dest_fd */
static void commit_blks(int dest_fd, char* buf, 
                        size_t size, bool is_hole) {

    if (size == 0) {
        return;
    }

    if (is_hole) {
        // create hole
        _lseek(dest_fd, size);
        
    } else {
        // write data on disk
        _write(dest_fd, buf, size);
    }
}


/* copy from src_fd to dest_fd with creating holes */
static bool sparse_copy(int src_fd, int dest_fd) {
    char buf[BUF_SIZE];
    ssize_t total_n_read, total_size;
    bool is_hole;
    char* start_blks_pointer;
    char* end_blks_pointer;


    while ((total_n_read = read(src_fd, buf, BUF_SIZE))) {
        if (total_n_read < 0) {
            return false;
        }
        total_size += total_n_read;
        size_t n_read = total_n_read;
        start_blks_pointer = end_blks_pointer = buf;
        is_hole = false;
        bool prev_hole = false;

        while (n_read > 0) {
            /* Last block processing */
            if (n_read < BLK_SIZE) {
                commit_blks(dest_fd, start_blks_pointer,
                            end_blks_pointer - start_blks_pointer, is_hole);
                _write(dest_fd, end_blks_pointer, n_read);
                break;
            }

            prev_hole = is_hole;
            is_hole = is_blk_nul(end_blks_pointer, BLK_SIZE);

            if (prev_hole == is_hole) {
                end_blks_pointer += BLK_SIZE;
            } else {
                commit_blks(dest_fd, start_blks_pointer,
                            end_blks_pointer - start_blks_pointer, prev_hole);
                start_blks_pointer = end_blks_pointer;
                end_blks_pointer += BLK_SIZE;
            }

            n_read -= BLK_SIZE;
        }

        commit_blks(dest_fd, start_blks_pointer,
                    end_blks_pointer - start_blks_pointer, is_hole);
    }

    if (ftruncate(dest_fd, total_size) < 0) {
        return false;
    }

    return true;
}


int main(int argc, char** argv) {
    if (argc < 2) {
        puts("Must be specified file name to write\n");
        return 1;
    }

    create_file_map = false;
    char* filename;
    for (int i = 1; i < argc; ++i) {
        if (strcmp(argv[i], "--create-file-map") == 0) {
            create_file_map = true;
        } else {
            filename = argv[i];
        }
    }

    ssize_t dest_fd = open(filename, O_WRONLY | O_CREAT | O_TRUNC, 0640);
    if (dest_fd < 0) {
        perror("open() ");
        return 1;
    }

    if (!sparse_copy(0, dest_fd)) {
        puts("Sparse is failed\n");
        return 1;   
    }

    close(dest_fd);

    return 0;
}