#!/usr/bin/python3
#
# Use the python imaging library to construct a difference image between the results
# and reference images

import sys
import os

from PIL import Image


def do_cmp():
    basedir = os.path.dirname(sys.argv[0])
    reference = os.path.join(basedir, 'Reference_Images')
    results = os.path.join(basedir, 'results')

    files = os.listdir(reference)

    for cand in files:
        if not cand.endswith('.jpg'):
            continue
        cand_result = os.path.join(results, cand)
        if not os.path.exists(cand_result):
            print(f"Missing results image: {cand}")
            continue
        ref1 = Image.open(os.path.join(reference, cand))
        result1 = Image.open(cand_result)
        if ref1.width != result1.width:
            print(f"{cand_result} and {cand} have different widths - Cannot compare")
        if ref1.height != result1.height:
            print(f"{cand_result} and {cand} have different heights - Cannot compare")
        diff = Image.new('RGB', (ref1.width, ref1.height))
        diff_name = cand_result.replace('.jpg','-diff.jpg')
        for x in range(ref1.width):
            for y in range(ref1.height):
                p1 = ref1.getpixel((x,y))
                p2 = result1.getpixel((x,y))
                val = [abs(p1[i] - p2[i]) for i in range(3)]
                val = tuple([x if x < 255 else 255 for x in val])
                diff.putpixel((x, y), val)
        diff.save(diff_name)


if __name__ == "__main__":
    do_cmp()

