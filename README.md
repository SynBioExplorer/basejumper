# Nanopore GUI Pipeline

An end-to-end desktop application for Nanopore data processing: basecalling, demultiplexing, run-level QC, **de novo Flye assembly**, optional reference-based evaluation, and summary statistics—all via a graphical interface.

---

## Quick Start (v1.0.0)

1. **Download** the `v1.0.0` release for your platform.  
2. **Extract** the archive.  
3. **Launch** the bundled executable (double-click or run from your file manager).  
4. The GUI will open directly, presenting the main menu:

   ![Main GUI](GUI_screenshot.png)

> **Note:**  
> - Assembly is performed **de novo** using Flye.  
> - If you opt to skip basecalling and demultiplexing in the GUI, prepare your input directory with subfolders named `Barcode01`, `Barcode02`, … corresponding exactly to the number of barcodes defined in the barcodes field.

---

## License

This project is released under the MIT License:

MIT License

Copyright (c) 2025 [Felix Meier]

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the “Software”), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
