import { ExternalTokenizer } from '@lezer/lr';
import {
  Transpose,
  CharArray,
  LineContinuation,
} from './matlab.grammar.terms';

// Character codes
const SINGLE_QUOTE = 39;        // '
const NEWLINE = 10;             // \n
const CARRIAGE_RETURN = 13;     // \r
const SPACE = 32;
const TAB = 9;
const DOT = 46;                 // .
const PAREN_R = 41;             // )
const BRACKET_R = 93;           // ]
const BRACE_R = 125;            // }
const UNDERSCORE = 95;          // _

function isDigit(ch: number) { return ch >= 48 && ch <= 57; }
function isLetter(ch: number) { return (ch >= 65 && ch <= 90) || (ch >= 97 && ch <= 122); }
function isNewline(ch: number) { return ch === NEWLINE || ch === CARRIAGE_RETURN; }

/**
 * Transpose vs. CharArray disambiguation.
 *
 * After an identifier, ), ], }, ., or digit → ' is Transpose.
 * Otherwise → ' starts a CharArray literal.
 *
 * CharArray: single-quoted strings where '' is the escape for a literal '.
 */
export const transposeToken = new ExternalTokenizer((input, stack) => {
  if (input.next !== SINGLE_QUOTE) return;

  // Look back: what was the previous non-whitespace character?
  // We check if the grammar just shifted an Identifier, Number, ), ], }, or .
  // The simplest heuristic: peek backward through the input.
  let isTranspose = false;
  let back = 1;
  while (input.peek(-back) === SPACE || input.peek(-back) === TAB) back++;
  const prev = input.peek(-back);
  if (
    prev === PAREN_R ||
    prev === BRACKET_R ||
    prev === BRACE_R ||
    prev === DOT ||
    isDigit(prev) ||
    isLetter(prev) ||
    prev === UNDERSCORE ||
    prev === SINGLE_QUOTE  // x'' = double transpose
  ) {
    isTranspose = true;
  }

  if (isTranspose) {
    input.advance(); // consume the '
    input.acceptToken(Transpose);
  } else {
    // CharArray: consume everything between '...' with '' as escape
    input.advance(); // consume opening '
    while (input.next >= 0) {
      if (input.next === SINGLE_QUOTE) {
        input.advance(); // consume '
        if (input.next === SINGLE_QUOTE) {
          // '' escape — continue
          input.advance();
        } else {
          // End of char array
          input.acceptToken(CharArray);
          return;
        }
      } else if (isNewline(input.next)) {
        // Unterminated — accept what we have
        input.acceptToken(CharArray);
        return;
      } else {
        input.advance();
      }
    }
    // EOF
    input.acceptToken(CharArray);
  }
});

/**
 * Line continuation: ... followed by anything until end of line.
 * Treated as whitespace (skipped).
 */
export const lineContinuationToken = new ExternalTokenizer((input) => {
  if (input.next !== DOT) return;
  if (input.peek(1) !== DOT || input.peek(2) !== DOT) return;

  // Consume the three dots
  input.advance(); input.advance(); input.advance();
  // Consume everything until newline
  while (input.next >= 0 && !isNewline(input.next)) input.advance();
  // Consume the newline itself
  if (input.next === CARRIAGE_RETURN) input.advance();
  if (input.next === NEWLINE) input.advance();

  input.acceptToken(LineContinuation);
});
