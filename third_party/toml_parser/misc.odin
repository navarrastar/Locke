package toml

import "core:fmt"
import "core:strings"
import "core:strconv"
import "core:unicode/utf8"

@private
find_newline :: proc(raw: string) -> (bytes: int, runes: int) {
    for r, i in raw {
        defer runes += 1
        if r == '\r' || r == '\n' do return i, runes
    }
    return -1, -1
}

@private
shorten_string :: proc(s: string, limit: int, or_newline := true) -> string {
    min :: proc(a, b: int) -> int {
        return a if a < b else b
    }

    newline, _ := find_newline(s) // add another line if you are using (..MAC OS 9) here... fuck it.
    if newline == -1 do newline = len(s)

    if limit < len(s) || newline < len(s) {
        return fmt.aprint(s[:min(limit, newline)], "...")
    }

    return s
}

// when literal is true, function JUST returns str
@private
cleanup_backslashes :: proc(str: string, literal := false) -> (result: string, err: Error) {
    str := strings.clone(str)
    if literal do return str, err

    set_err :: proc(err: ^Error, type: ErrorType, more_fmt: string, more_args: ..any) {
        err.type = type
        b_printf(&err.more, more_fmt, ..more_args)
    }

    using strings
    b: Builder
    // defer builder_destroy(&b) // don't need to, shouldn't even free the original str here

    to_skip := 0

    last: rune
    escaped: bool
    for r, i in str {

        if to_skip > 0 {
            to_skip -= 1
            continue
        }
        // basically, if last == '\\' {
        if escaped {
            escaped = false

            switch r {
            case 'u': // for \uXXXX
                if len(str) < i + 5 {
                    set_err(&err, .Bad_Unicode_Char, "'\\u' does most have hex 4 digits after it in string:", str)
                    return str, err
                }

                code, ok := strconv.parse_u64(str[i + 1: i + 5], 16)
                buf, bytes := toml_ucs_to_utf8(code)

                if bytes == -1 {
                    set_err(&err, .Bad_Unicode_Char, "'%s'", str[i + 1:i + 5])
                    return str, err
                }

                parsed_rune, _ := utf8.decode_rune_in_bytes(buf[:bytes])
                
                write_rune(&b, parsed_rune)
                to_skip = 4

            case 'U': // for \UXXXXXXXX
                if len(str) < i + 9 {
                    set_err(&err, .Bad_Unicode_Char, "'\\U' does most have hex 8 digits after it in string:", str)
                    return str, err
                }
                code, ok := strconv.parse_u64(str[i + 1:i + 9], 16)
                buf, bytes := toml_ucs_to_utf8(code)

                if bytes == -1 {
                    set_err(&err, .Bad_Unicode_Char, "'%s'", str[i + 1:i + 9])
                    return str, err
                }
                
                parsed_rune, _ := utf8.decode_rune_in_bytes(buf[:bytes])
                
                write_rune(&b, parsed_rune)
                to_skip = 8

            case 'x':
                set_err(&err, .Bad_Unicode_Char, "\\xXX is not in the spec, you can just use \\u00XX instead.")
                return str, err

            case 'n' : write_byte(&b, '\n')
            case 'r' : write_byte(&b, '\r')
            case 't' : write_byte(&b, '\t')
            case 'b' : write_byte(&b, '\b')
            case 'f' : write_byte(&b, '\f')
            case '\\': write_byte(&b, '\\')
            case '"' : write_byte(&b, '"')
            case '\'': write_byte(&b, '\'')
            case ' ', '\t', '\r', '\n': 
                // if (r == ' ' || r == '\t') && len(str) > i + 1 && (str[i + 1] != '\n' || str[i + 1] != '\r') {
                //     err.type = .Bad_Unicode_Char
                //     err.more = "cannot escape space in the middle of the line."
                // }
                // if len(str) == i + 1 {
                //     err.type = .Bad_Unicode_Char
                //     err.more = "Cannot escape space/new line when it is the last character"
                // }
                
                // Fun thing for multiline line string line escaping.
                for r in str[i + 1:] {
                    if r == ' ' || r == '\t' || r == '\r' || r == '\n' do to_skip += 1
                    else do break
                }
            case: 
                set_err(&err, .Bad_Unicode_Char, "Unexpected escape sequence found."); 
                return str, err
            }
        } else if r != '\\' {
            write_rune(&b, r)
        } else {
            escaped = true
        }

        last = r
    }
    delete_string(str)
    defer b_destroy(&b) // you can't free a builder that has been cast to string
    return strings.clone(to_string(b)), err
}

@private
any_of :: proc(a: $T, B: ..T) -> bool {
    for b in B do if a == b do return true
    return false
}

@private
is_space :: proc(r: u8) -> bool {
    SPACE : [4] u8 = { ' ', '\r', '\n', '\t' }
    return r == SPACE[0] || r == SPACE[1] || r == SPACE[2] || r == SPACE[3]
    // Nudge nudge
} 

@private
is_special :: proc(r: u8) -> bool {
    SPECIAL : [8] u8 = { '=', ',',  '.',  '[', ']', '{', '}', 0 }
    return  r == SPECIAL[0] || r == SPECIAL[1] || r == SPECIAL[2] || r == SPECIAL[3] ||
            r == SPECIAL[4] || r == SPECIAL[5] || r == SPECIAL[6] || r == SPECIAL[7]
    // Shove shove
} 

@private
is_digit :: proc(r: rune, base: int) -> bool {
    switch base {
    case 16: return (r >= '0' && r <= '9') || (r >= 'A' && r <= 'F') || (r >= 'a' && r <= 'f')
    case 10: return r >= '0' && r <= '9'
    case 8:  return r >= '0' && r <= '7'
    case 2:  return r >= '0' && r <= '1'
    }
    assert(false, "Only bases: 16, 10, 8 and 2 are supported in TOML")
    return false
}

@private
between_any :: proc(a: rune, b: ..rune) -> bool {
    assert(len(b) % 2 == 0)
    for i := 0; i < len(b); i += 2 {
        if a >= b[i] && a <= b[i + 1] do return true
    }
    return false
}

@(private)
get_quote_count :: proc(a: string) -> int {
    s := len(a)
    if  s > 2 && 
        ((a[:3] == "\"\"\"" && a[s-3:] == "\"\"\"" ) ||
        (a[:3] == "'''" && a[s-3:] == "'''")) { return 3 }

    if  s > 0 && 
        ((a[:1] == "\"" && a[s-1:] == "\"") ||
        (a[:1] == "'" && a[s-1:] == "'")) { return 1 }

    return 0
}

@(private)
unquote :: proc(a: string, fluff: ..any) -> (result: string, err: Error) {
    qcount := get_quote_count(a)

    if qcount == 3 {
        first: rune
        count: int
        #reverse for r, i in a {
            if i < 3 do break
            if first == 0 do first = r
            if r == first do count = count + 1
            else if r == '\\' do count -= 1
            else do break
        }
        if count != 3 && count % 3 == 0 {
            err.type = .Bad_Value
            b_write_string(&err.more, "The quote count in multiline string is divisible by 3. Lol, get fucked!")
            return a, err
        }
    }

    unquoted := a[qcount:len(a) - qcount]
    if len(unquoted) > 0 && unquoted[0] == '\n' do unquoted = unquoted[1:]
    return cleanup_backslashes(unquoted, a[0] == '\'')
}

@(private)
starts_with :: proc(a, b: string) -> bool {
    return len(a) >= len(b) && a[:len(b)] == b
}

@(private)
ends_with :: proc(a, b: string) -> bool {
    return len(a) >= len(b) && a[len(a) - len(b):] == b
}

// case-insensitive compare
@private
eq :: proc(a, b: string) -> bool {
    if len(a) != len(b) do return false
    #no_bounds_check for i in 0..<len(a) {
        r1 := a[i]
        r2 := b[i]

        A := r1 - 32*u8(r1 >= 'a' && r1 <= 'z')
        B := r2 - 32*u8(r2 >= 'a' && r2 <= 'z')
        if A != B do return false
    }
    return true
}

@private
is_list :: proc(t: Type) -> bool { 
    _, is_list := t.(^List); 
    return is_list
    
}

// // from: https://www.cl.cam.ac.uk/~mgk25/ucs/utf8_check.c
// is_rune_valid :: proc(r: rune) -> bool {
//     // if !utf8.valid_rune(r) do return false
// 
//     s, n := utf8.encode_rune(r)
// 
//     if n == 1 {
//         /* 0xxxxxxx */
//         return true
//     } else if n == 2 {
//         /* 110XXXXx 10xxxxxx */
//         if ((s[1] & 0xc0) != 0x80 ||
//             (s[0] & 0xfe) == 0xc0) {                      /* overlong? */
//             return true
//         }
//     } else if n == 3 {
//         /* 1110XXXX 10Xxxxxx 10xxxxxx */
//         if ((s[1] & 0xc0) != 0x80 ||
//             (s[2] & 0xc0) != 0x80 ||
//             (s[0] == 0xe0 && (s[1] & 0xe0) == 0x80) ||    /* overlong? */
//             (s[0] == 0xed && (s[1] & 0xe0) == 0xa0) ||    /* surrogate? */
//             (s[0] == 0xef && s[1] == 0xbf &&
//                 (s[2] & 0xfe) == 0xbe)) {                    /* U+FFFE or U+FFFF? */
//             return true
//         }
//     } else if n == 4 {
//         /* 11110XXX 10XXxxxx 10xxxxxx 10xxxxxx */
//         if ((s[1] & 0xc0) != 0x80 ||
//             (s[2] & 0xc0) != 0x80 ||
//             (s[3] & 0xc0) != 0x80 ||
//             (s[0] == 0xf0 && (s[1] & 0xf0) == 0x80) ||      /* overlong? */
//             (s[0] == 0xf4 && s[1] > 0x8f) || s[0] > 0xf4) { /* > U+10FFFF? */
//             return true
//         }
//     } else do return false
// 
//     return true
// }

is_bare_rune_valid :: proc(r: rune) -> bool {
    if r == '\n' || r == '\r' || r == '\t' do return true
    return r >= 32
}


// Completely ripped from tomlc99:
// https://github.com/cktan/tomlc99

/**
 *	Convert a UCS char to utf8 code, and return it in buf.
 *	Return #bytes used in buf to encode the char, or
 *	-1 on error.
 */
toml_ucs_to_utf8 :: proc(code: u64) -> (buf: [6] u8, byte_count: int) {
    /* http://stackoverflow.com/questions/6240055/manually-converting-unicode-codepoints-into-utf-8-and-utf-16
     */
    /* The UCS code values 0xd800–0xdfff (UTF-16 surrogates) as well
     * as 0xfffe and 0xffff (UCS noncharacters) should not appear in
     * conforming UTF-8 streams.
     */
    if (0xd800 <= code && code <= 0xdfff) do return buf, -1
    // if (0xfffe <= code && code <= 0xffff) do return buf, -1

    /* 0x00000000 - 0x0000007F:
        0xxxxxxx
    */
    if (code < 0) do return buf, -1;
    if (code <= 0x7F) {
        buf[0] = u8(code);
        return buf, 1;
    }

    /* 0x00000080 - 0x000007FF:
       110xxxxx 10xxxxxx
    */
    if (code <= 0x000007FF) {
        buf[0] = u8(0xc0 | (code >> 6));
        buf[1] = u8(0x80 | (code & 0x3f));
        return buf, 2;
    }

    /* 0x00000800 - 0x0000FFFF:
       1110xxxx 10xxxxxx 10xxxxxx
    */
    if (code <= 0x0000FFFF) {
        buf[0] = u8(0xe0 | (code >> 12));
        buf[1] = u8(0x80 | ((code >> 6) & 0x3f));
        buf[2] = u8(0x80 | (code & 0x3f));
        return buf, 3;
    }

    /* 0x00010000 - 0x001FFFFF:
       11110xxx 10xxxxxx 10xxxxxx 10xxxxxx
    */
    if (code <= 0x001FFFFF) {
        buf[0] = u8(0xf0 | (code >> 18));
        buf[1] = u8(0x80 | ((code >> 12) & 0x3f));
        buf[2] = u8(0x80 | ((code >> 6) & 0x3f));
        buf[3] = u8(0x80 | (code & 0x3f));
        return buf, 4;
    }

    /* 0x00200000 - 0x03FFFFFF:
       111110xx 10xxxxxx 10xxxxxx 10xxxxxx 10xxxxxx
     */
    if (code <= 0x03FFFFFF) {
        buf[0] = u8(0xf8 | (code >> 24));
        buf[1] = u8(0x80 | ((code >> 18) & 0x3f));
        buf[2] = u8(0x80 | ((code >> 12) & 0x3f));
        buf[3] = u8(0x80 | ((code >> 6) & 0x3f));
        buf[4] = u8(0x80 | (code & 0x3f));
        return buf, 5;
    }

    /* 0x04000000 - 0x7FFFFFFF:
       1111110x 10xxxxxx 10xxxxxx 10xxxxxx 10xxxxxx 10xxxxxx
     */
    if (code <= 0x7FFFFFFF) {
        buf[0] = u8(0xfc | (code >> 30));
        buf[1] = u8(0x80 | ((code >> 24) & 0x3f));
        buf[2] = u8(0x80 | ((code >> 18) & 0x3f));
        buf[3] = u8(0x80 | ((code >> 12) & 0x3f));
        buf[4] = u8(0x80 | ((code >> 6) & 0x3f));
        buf[5] = u8(0x80 | (code & 0x3f));
        return buf, 6;
    }

    return buf, -1;
}



