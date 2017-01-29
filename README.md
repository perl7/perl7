# Perl 7: The up-to-date Perl

![](https://avatars2.githubusercontent.com/u/25326498?v=3&s=200)

## FUNCTIONS

### `say`

```
    say 'Hello, World!'
```

Prints text to STDOUT adding a newline at the end.

## VARIABLES

Unlike previous Perls, Perl 7 no longer has sigils on variables nor do they
need any declarators and are simply declared on first use:

```
    a = 2.4
    b = -2.5
    say a * b * b # 15
    b = 42
    say a * b * b # 4233.6
```

## CONDITIONALS

### `if`

```
if 42
    say "foo"
end
```

### `if`/`else`

```
if "meow"
    say "foo"
else
    say "bar"
end
```

### `while`

```
a = 10
while a > 0
    a = a - 1
    say a
end
```

## OPERATORS

The currently supported operators are:

- `=` assignment operator
- `*` Multiply
- `/` Divide
- `-` Subtract
- `+` Add
- `<` numerically less-than
- `>` numerically more-than
- `<=` numerically less-than or equal-to
- `>=` numerically more-than or equal-to
- `!=` numerically not equal to
- `==` numerically equal to

## USER DECLARED FUNCTIONS

Both methods and functions are declared with keyword `routine`

```
routine greet
    say "hi"
end
```

To call the function later, simply write its name:

```
greet  # prints "hi"
```

You can specify parameters with parentheses:

```
routine calc-it(a, b, c)
    say a + b + c
end
calc-it(10, 20, 12) # prints 42
```

## Object Orientation

Classes are declared with a `class` keyword followed by a class name. `.new`
method call creates a new object and `.foo` or `.foo(some, args)` is a method
call.

```
class Foo
    routine foo(a)
        say a
    end
end
a = Foo.new
a.foo(42)
```

### LICENSE

See [LICENSE](LICENSE) file for details.
