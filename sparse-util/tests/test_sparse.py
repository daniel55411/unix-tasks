import os
import os.path
import re
import subprocess
import unittest

from typing import List


SPARSE_PATH = os.path.abspath(
    os.path.join(
        os.path.dirname(__file__),
        os.path.pardir,
        'sparse'
    )
)
BLK_SIZE = 128
HALF_BLK_SIZE = BLK_SIZE // 2
QUARTER_BLK_SIZE = BLK_SIZE // 4


def _create_zero_block():
    return b'\x00' * BLK_SIZE


def _create_one_block():
    return b'\x01' * BLK_SIZE


def _create_non_empty_block():
    return (b'\x01' * QUARTER_BLK_SIZE +
            b'\x00' * HALF_BLK_SIZE +
            b'\x01' * QUARTER_BLK_SIZE)


def _create_not_full_block(value, size):
    assert isinstance(value, bytes)
    assert size < BLK_SIZE

    return value * size


class SparseTest(unittest.TestCase):
    TEST_FILE_NAME = 'test_file'

    def tearDown(self) -> None:
        if os.path.exists(self.TEST_FILE_NAME):
            os.remove(self.TEST_FILE_NAME)

    def test_empty_file(self):
        input_bytes = _create_zero_block() * 9

        self.assert_output_sparsed(input_bytes)

    def test_non_empty_file(self):
        input_bytes = _create_one_block() * 3

        self.assert_output_sparsed(input_bytes)

    def test_one_non_empty_block_in_end_of_file(self):
        input_bytes = (_create_zero_block() * 32
                       + _create_non_empty_block())

        self.assert_output_sparsed(input_bytes)

    def test_one_non_empty_block_in_begin_of_file(self):
        input_bytes = (_create_non_empty_block()
                       + _create_zero_block() * 16)

        self.assert_output_sparsed(input_bytes)

    def test_one_non_empty_block_in_middle_of_file(self):
        input_bytes = (_create_zero_block() * 8
                       + _create_non_empty_block()
                       + _create_zero_block() * 8)

        self.assert_output_sparsed(input_bytes)

    def test_three_non_empty_block(self):
        input_bytes = (_create_non_empty_block() * 3
                       + _create_zero_block() * 8)

        self.assert_output_sparsed(input_bytes)

    def test_not_full_one_block(self):
        input_bytes = (_create_zero_block() * 12
                       + _create_not_full_block(value=b'\x01', size=65))

        self.assert_output_sparsed(input_bytes)

    def test_not_full_zero_block(self):
        input_bytes = (_create_zero_block() * 12
                       + _create_not_full_block(value=b'\x00', size=65))

        self.assert_output_sparsed(input_bytes)

    def assert_output_sparsed(self, input_bytes):
        assert isinstance(input_bytes, bytes), "input_bytes must be bytes"

        file_map_info = subprocess.check_output(
            [SPARSE_PATH, self.TEST_FILE_NAME, '--create-file-map'],
            input=input_bytes
        ).decode().split('\n')
        if file_map_info[-1] == '':
            file_map_info.pop()

        # Check file is sparsed by file map from program output
        self.assert_file_map(file_map_info, input_bytes)

        with open(self.TEST_FILE_NAME, 'rb') as f:
            actual = f.read()
            self.assertEqual(actual, input_bytes, "Content is not as expected")

        stats = os.stat(self.TEST_FILE_NAME)
        self.assertEqual(stats.st_size, len(input_bytes), "Result size is not as input size")

    def assert_file_map(self, file_map_info: List[str], expected):
        pointer = 0
        for info in file_map_info:
            match = re.fullmatch(r'^(WRITE|SEEK) blk_count=(\d+?)$', info)
            assert match is not None, "Wrong file block info"
            blk_type, blk_count = match.group(1), int(match.group(2))

            size = BLK_SIZE * blk_count
            actual_block = expected[pointer: pointer + size]
            expected_block = b'\x00' * size
            if blk_type == 'SEEK':
                self.assertEqual(
                    actual_block, expected_block,
                    'Block is not nul but it must be nul'
                )
            else:
                self.assertNotEqual(
                    actual_block, expected_block,
                    'Block is nul but it must not be nul'
                )

            pointer += size


if __name__ == '__main__':
    unittest.main()
