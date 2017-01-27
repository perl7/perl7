# Perl 7: The up-to-date Perl

![](https://avatars2.githubusercontent.com/u/25326498?v=3&s=200)

## FUNCTIONS

### `💬` `U+1F4AC`

```
    💬 'Hello, World!'
```

Prints text to STDOUT adding a newline at the end.

## VARIABLES

Unlike previous Perls, Perl 7 no longer has sigils on variables nor do they
need any declarators and are simply declared on first use:

```
    a = 2.4
    b = −2.5
    💬 a × b × b # 15
    b = 42
    💬 a × b × b # 4233.6
```

## OPERATORS

**Note:** Perl 7 fully embraces the entire Unicode range and so traditional
symbols that are mis-used in other languages (e.g. `*` for multiplication) are
no longer valid.

The currently supported operators are:

- `×` `U+00D7` Multiply
- `÷` `U+00F7` Divide
- `−` `U+2212` Subtract
- `+` `U+002B` Add

## USER DECLARED FUNCTIONS

Functions in Perl 7 are trivial to declare and need no ugly braces or anything
like that. They're started with word `fun` followed by
space and the function's name, followed by function's body, followed by word
`ion`. Mnemonic: **fun**ct**ion**

```
fun greet
    💬 hi
ion
```

To call the function later, simply write its name:

```
greet  # prints "hi"
```

### LICENSE

See [LICENSE](LICENSE) file for details.
