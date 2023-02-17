# Typing os env vars

https://stackoverflow.com/questions/40145569/how-do-you-make-a-function-accept-multiple-types
```
Starting with Go 1.18. you can use generics to specify which types can be used in a function.

func print_out_type[T any](x T) string {
    return fmt.Sprintf("%T", x)
}
```

```
"strconv"
// "bytes"
errs <- http.ListenAndServe(":"+strconv.Itoa(httpPort), mux)
```
