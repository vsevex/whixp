// Direct translation from RFC 3492 C-code to Dart-code

// -- /*
// -- punycode.c from RFC 3492
// -- http://www.nicemice.net/idn/
// -- Adam M. Costello
// -- http://www.nicemice.net/amc/
// --
// -- This is ANSI C code (C89) implementing Punycode (RFC 3492).
// --
// -- */
// -- enum { base = 36, tmin = 1, tmax = 26, skew = 38, damp = 700,
// --        initial_bias = 72, initial_n = 0x80, delimiter = 0x2D };

import 'package:whixp/src/exception.dart';

const int _base = 36;
const int _tMin = 1;
const int _tMax = 26;
const int _skew = 38;
const int _damp = 700;
const int _initialBias = 72;
const int _initialN = 128; // = 0x80
const int _delimiter = 0x2D;

// --
// -- /* basic(cp) tests whether cp is a basic code point: */
// -- #define basic(cp) ((punycode_uint)(cp) < 0x80)
bool _isBasic(int cp) => cp < 0x80;

// --
// -- /* delim(cp) tests whether cp is a delimiter: */
// -- #define delim(cp) ((cp) == delimiter)
bool _isDelim(int cp) => cp == _delimiter;

// -- /* decode_digit(cp) returns the numeric value of a basic code */
// -- /* point (for use in representing integers) in the range 0 to */
// -- /* base-1, or base if cp is does not represent a value.       */
// --
// -- static punycode_uint decode_digit(punycode_uint cp)
// -- {
// --   return  cp - 48 < 10 ? cp - 22 :  cp - 65 < 26 ? cp - 65 :
// --           cp - 97 < 26 ? cp - 97 :  base;
// -- }
int _decodeDigit(int cp) {
  return cp - 48 < 10
      ? cp - 22
      : cp - 65 < 26
          ? cp - 65
          : cp - 97 < 26
              ? cp - 97
              : _base;
}

// -- /* encode_digit(d,flag) returns the basic code point whose value      */
// -- /* (when used for representing integers) is d, which needs to be in   */
// -- /* the range 0 to base-1.  The lowercase form is used unless flag is  */
// -- /* nonzero, in which case the uppercase form is used.  The behavior   */
// -- /* is undefined if flag is nonzero and digit d has no uppercase form. */
// --
// -- static char encode_digit(punycode_uint d, int flag)
// -- {
// --   return d + 22 + 75 * (d < 26) - ((flag != 0) << 5);
// --   /*  0..25 map to ASCII a..z or A..Z */
// --   /* 26..35 map to ASCII 0..9         */
// -- }
int _encodeDigit(int d, bool upperCase) {
  var digit = d + 22;
  if (d < 26) {
    digit += 75;
  }
  if (upperCase) {
    digit -= 1 << 5;
  }
  return digit;
}

// -- /* flagged(bcp) tests whether a basic code point is flagged */
// -- /* (uppercase).  The behavior is undefined if bcp is not a  */
// -- /* basic code point.                                        */
// --
// -- #define flagged(bcp) ((punycode_uint)(bcp) - 65 < 26)
//bool _isFlagged(int bcp) => (bcp - 65) < 26;

// -- /* encode_basic(bcp,flag) forces a basic code point to lowercase */
// -- /* if flag is zero, uppercase if flag is nonzero, and returns    */
// -- /* the resulting code point.  The code point is unchanged if it  */
// -- /* is caseless.  The behavior is undefined if bcp is not a basic */
// -- /* code point.                                                   */
// --
// -- static char encode_basic(punycode_uint bcp, int flag)
// -- {
// --   bcp -= (bcp - 97 < 26) << 5;
// --   return bcp + ((!flag && (bcp - 65 < 26)) << 5);
// -- }
int _encodeBasic(int bcp, bool upperCase) {
  int temp = bcp;
  temp -= (bcp - 97 < 26) ? 1 << 5 : 0;
  return temp + ((!upperCase && (temp - 65 < 26)) ? 1 << 5 : 0);
}

// -- static punycode_uint adapt(
// --   punycode_uint delta, punycode_uint numpoints, int firsttime )
// -- {
// --   punycode_uint k;
// --
// --   delta = firsttime ? delta / damp : delta >> 1;
// --   /* delta >> 1 is a faster way of doing delta / 2 */
// --   delta += delta / numpoints;
// --
// --   for (k = 0;  delta > ((base - tmin) * tmax) / 2;  k += base) {
// --     delta /= base - tmin;
// --   }
// --
// --   return k + (base - tmin + 1) * delta / (delta + skew);
// -- }
int _adapt(int delta, int numPoints, bool firstTime) {
  int tempDelta = delta;
  int k;
  tempDelta = firstTime ? tempDelta ~/ _damp : tempDelta ~/ 2;
  tempDelta += tempDelta ~/ numPoints;

  for (k = 0; tempDelta > ((_base - _tMin) * _tMax) ~/ 2; k += _base) {
    tempDelta ~/= _base - _tMin;
  }

  return k + (_base - _tMin + 1) * tempDelta ~/ (tempDelta + _skew);
}

// -- /*** Main encode function ***/
// --
// -- enum punycode_status punycode_encode(
// --   punycode_uint input_length,
// --   const punycode_uint input[],
// --   const unsigned char case_flags[],
// --   punycode_uint *output_length,
// --   char output[] )
String punycodeEncode(String inputString, {bool upperCase = false}) {
  final input = inputString.runes.toList(growable: false);

  final output = StringBuffer();
  void toOut(int c) => output.writeCharCode(c);
  void allToOut(Iterable<int> cps) {
    for (final codepoint in cps) {
      output.writeCharCode(codepoint);
    }
  }

  // -- {
  // --   punycode_uint n, delta, h, b, out, max_out, bias, j, m, q, k, t;
  // --   /* Initialize the state: */
  // --
  // --   n = initial_n;
  // --   delta = out = 0;
  // --   max_out = *output_length;
  // --   bias = initial_bias;
  int n = _initialN;
  int delta = 0;
  late int h;
  late int b;
  int bias = _initialBias;
  int j = 0;
  int? m;
  int q;
  int k;
  int t;

  // --   /* Handle the basic code points: */
  // --   for (j = 0;  j < input_length;  ++j) {
  // --     if (basic(input[j])) {
  // --       if (max_out - out < 2) return punycode_big_output;
  // --       output[out++] =
  // --         case_flags ?  encode_basic(input[j], case_flags[j]) : input[j];
  // --     }
  // --     /* else if (input[j] < n) return punycode_bad_input; */
  // --     /* (not needed for Punycode with unsigned code points) */
  // --   }
  allToOut(input.where(_isBasic).map((r) => _encodeBasic(r, upperCase)));

  // --   h = b = out;
  h = b = output.length;

  // --   /* h is the number of code points that have been handled, b is the  */
  // --   /* number of basic code points, and out is the number of characters */
  // --   /* that have been output.                                           */
  // --
  // --   if (b > 0) output[out++] = delimiter;
  if (b > 0) toOut(_delimiter);

  // --   /* Main encoding loop: */
  // --
  // --   while (h < input_length) {
  while (h < input.length) {
    // --     /* All non-basic code points < n have been     */
    // --     /* handled already.  Find the next larger one: */
    // --
    // --     for (m = maxint, j = 0;  j < input_length;  ++j) {
    // --       /* if (basic(input[j])) continue; */
    // --       /* (not needed for Punycode) */
    // --       if (input[j] >= n && input[j] < m) m = input[j];
    // --     }
    m = null;
    for (j = 0; j < input.length; j++) {
      final i = input[j];
      if (i >= n && (m == null || i < m)) {
        m = i;
      }
    }

    // --     /* Increase delta enough to advance the decoder's    */
    // --     /* <n,i> state to <m,0>, but guard against overflow: */
    // --
    // --     if (m - n > (maxint - delta) / (h + 1)) return punycode_overflow;
    // Currently no overflow protection.

    // --     delta += (m - n) * (h + 1);
    // --     n = m;
    delta += (m! - n) * (h + 1);
    n = m;

    // --     for (j = 0;  j < input_length;  ++j) {
    for (j = 0; j < input.length; j++) {
      // --       /* Punycode does not need to check whether input[j] is basic: */
      // --       if (input[j] < n /* || basic(input[j]) */ ) {
      // --         if (++delta == 0) return punycode_overflow;
      // --       }
      // Currently no overflow protection.
      if (input[j] < n) {
        delta++;
      }

      // --       if (input[j] == n) {
      // --         /* Represent delta as a generalized variable-length integer: */
      // --
      // --         for (q = delta, k = base;  ;  k += base) {
      // --           if (out >= max_out) return punycode_big_output;
      // --           t = k <= bias /* + tmin */ ? tmin :     /* +tmin not needed */
      // --               k >= bias + tmax ? tmax : k - bias;
      // --           if (q < t) break;
      // --           output[out++] = encode_digit(t + (q - t) % (base - t), 0);
      // --           q = (q - t) / (base - t);
      // --         }
      if (input[j] == n) {
        q = delta;
        k = _base;
        for (;; k += _base) {
          t = k <= bias
              ? _tMin
              : k >= bias + _tMax
                  ? _tMax
                  : k - bias;
          if (q < t) break;
          toOut(_encodeDigit(t + (q - t) % (_base - t), false));
          q = (q - t) ~/ (_base - t);
        }

        // --         output[out++] = encode_digit(q, case_flags && case_flags[j]);
        // --         bias = adapt(delta, h + 1, h == b);
        // --         delta = 0;
        // --         ++h;
        toOut(_encodeDigit(q, upperCase));
        bias = _adapt(delta, h + 1, h == b);
        delta = 0;
        h++;
        // --       }
      }
      // --     }
    }

    // --     ++delta, ++n;
    delta++;
    n++;
    // --   }
  }

  // --   *output_length = out;
  // --   return punycode_success;
  // -- }
  return output.toString();
}

// -- /*** Main decode function ***/
// --
// -- enum punycode_status punycode_decode(
// --   punycode_uint input_length,
// --   const char input[],
// --   punycode_uint *output_length,
// --   punycode_uint output[],
// --   unsigned char case_flags[] )
String punycodeDecode(String inputString) {
  final input = inputString.codeUnits;
  // -- {
  // --   punycode_uint n, out, i, max_out, bias,
  // --                  b, j, in, oldi, w, k, digit, t;
  // --   /* Initialize the state: */
  // --
  // --   n = initial_n;
  // --   out = i = 0;
  // --   max_out = *output_length;
  // --   bias = initial_bias;
  final output = <int>[];
  int n = _initialN;
  int i = 0;
  int bias = _initialBias;
  int b;
  int j;
  int iin;
  int oldI;
  int w;
  int k;
  int digit;
  int t;

  // --   /* Handle the basic code points:  Let b be the number of input code */
  // --   /* points before the last delimiter, or 0 if there is none, then    */
  // --   /* copy the first b code points to the output.                      */
  // --
  // --   for (b = j = 0;  j < input_length;  ++j) if (delim(input[j])) b = j;
  for (b = j = 0; j < input.length; j++) {
    if (_isDelim(input[j])) {
      b = j;
    }
  }

  // This shouldn't be possible.
  // --   if (b > max_out) return punycode_big_output;

  // --   for (j = 0;  j < b;  ++j) {
  // --     if (case_flags) case_flags[out] = flagged(input[j]);
  // --     if (!basic(input[j])) return punycode_bad_input;
  // --     output[out++] = input[j];
  // --   }
  for (j = 0; j < b; j++) {
    if (!_isBasic(input[j])) {
      throw StringPreparationException.punycode(
        'Bad input while decoding punycode',
      );
    }
    output.add(input[j]);
  }

  // --   /* Main decoding loop:  Start just after the last delimiter if any  */
  // --   /* basic code points were copied; start at the beginning otherwise. */
  // --
  // --   for (in = b > 0 ? b + 1 : 0;  in < input_length;  ++out) {
  for (iin = b > 0 ? b + 1 : 0; iin < input.length;) {
    // --     /* in is the index of the next character to be consumed, and */
    // --     /* out is the number of code points in the output array.     */
    // --
    // --     /* Decode a generalized variable-length integer into delta,  */
    // --     /* which gets added to i.  The overflow checking is easier   */
    // --     /* if we increase i as we go, then subtract off its starting */
    // --     /* value at the end to obtain delta.                         */
    // --
    // --     for (oldi = i, w = 1, k = base;  ;  k += base) {
    // --       if (in >= input_length) return punycode_bad_input;
    // --       digit = decode_digit(input[in++]);
    // --       if (digit >= base) return punycode_bad_input;
    // --       if (digit > (maxint - i) / w) return punycode_overflow;
    // --       i += digit * w;
    // --       t = k <= bias /* + tmin */ ? tmin :     /* +tmin not needed */
    // --           k >= bias + tmax ? tmax : k - bias;
    // --       if (digit < t) break;
    // --       if (w > maxint / (base - t)) return punycode_overflow;
    // --       w *= (base - t);
    // --     }
    oldI = i;
    w = 1;
    k = _base;
    for (;; k += _base) {
      // ignore: invariant_booleans
      if (iin >= input.length) {
        throw StringPreparationException.punycode(
          'Bad input while decoding punycode',
        );
      }
      digit = _decodeDigit(input[iin++]);
      if (digit >= _base) {
        throw StringPreparationException.punycode(
          'Bad input while decoding punycode',
        );
      }
      i += digit * w;
      t = k <= bias
          ? _tMin
          : k >= bias + _tMax
              ? _tMax
              : k - bias;
      if (digit < t) break;
      w *= _base - t;
    }

    // --     bias = adapt(i - oldi, out + 1, oldi == 0);
    bias = _adapt(i - oldI, output.length + 1, oldI == 0);

    // --     /* i was supposed to wrap around from out+1 to 0,   */
    // --     /* incrementing n each time, so we'll fix that now: */
    // --
    // --     if (i / (out + 1) > maxint - n) return punycode_overflow;
    // --     n += i / (out + 1);
    // --     i %= (out + 1);
    n += i ~/ (output.length + 1);
    i %= output.length + 1;

    // --     /* Insert n at position i of the output: */
    // --
    // --     /* not needed for Punycode: */
    // --     /* if (decode_digit(n) <= base) return punycode_invalid_input; */
    // --     if (out >= max_out) return punycode_big_output;

    // --     if (case_flags) {
    // --       memmove(case_flags + i + 1, case_flags + i, out - i);
    // --       /* Case of last character determines uppercase flag: */
    // --       case_flags[i] = flagged(input[in - 1]);
    // --     }

    // --     memmove(output + i + 1, output + i, (out - i) * sizeof *output);
    // --     output[i++] = n;
    output.insert(i++, n);
    // --   }
  }

  // --   *output_length = out;
  // --   return punycode_success;
  return String.fromCharCodes(output);
  // -- }
}
