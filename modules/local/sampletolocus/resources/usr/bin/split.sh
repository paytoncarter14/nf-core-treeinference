#!/bin/bash
grep -A1 "^>${1}$" ${2} | sed 's|^>.*$|>'"$(basename ${2} .fasta)"'|g' >> loci/${1}.fasta || true
