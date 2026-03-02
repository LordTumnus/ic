/**
 * Unit tests for the MATLAB Lezer grammar.
 *
 * Uses @lezer/generator's fileTests format: each .txt file contains
 * test cases with input code and expected parse tree specs.
 *
 * Custom mayIgnore: also ignores `newline` tokens since they serve as
 * structural separators in our grammar but are noise in tree assertions.
 */

import { describe, it } from 'vitest';
import { fileTests } from '@lezer/generator/test';
import { NodeType } from '@lezer/common';
import { readFileSync, readdirSync } from 'fs';
import { join } from 'path';
import { parser } from '$lib/languages/matlab/matlab.grammar';

const testDir = join(__dirname, '../../src/lib/languages/matlab/test');

/**
 * Custom ignore function: skip punctuation tokens (default behavior)
 * AND `newline` tokens which are structural separators in the grammar.
 */
function mayIgnore(type: NodeType): boolean {
  return /\W/.test(type.name) || type.name === 'newline';
}

describe('MATLAB Grammar', () => {
  const files = readdirSync(testDir).filter((f) => f.endsWith('.txt'));

  for (const file of files) {
    describe(file.replace('.txt', ''), () => {
      const content = readFileSync(join(testDir, file), 'utf-8');
      const tests = fileTests(content, file, mayIgnore);

      for (const test of tests) {
        it(test.name, () => {
          test.run(parser);
        });
      }
    });
  }
});
