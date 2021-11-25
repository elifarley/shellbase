[![GitHub tag](https://img.shields.io/github/tag/elifarley/shellbase.svg?maxAge=2592000)](https://github.com/elifarley/shellbase)
[![Github All Releases](https://img.shields.io/github/downloads/elifarley/shellbase/total.svg?maxAge=2592000)](https://github.com/elifarley/shellbase)

# shellbase
Some useful shell scripting functions and customizations

## See Also
- https://github.com/Offirmo/offirmo-shell-lib
- https://dotfiles.github.io/

# Tips
- [Prefer](https://unix.stackexchange.com/a/62883/46796) `[` (or `test`) over `[[`:
@Tobia, `[` is a standard command. It's not so much that command that is horrible but the way Bourne-like shells parse command lines. `[[...]]` is a ksh construct that has issues of its own in various shells. For instance, until recently `[[ $(...) ]]` wouldn't work in zsh (you needed `[[ -n $(...) ]]`). Except in zsh, you need quotes in `[[ $a = $b ]]`, the `[[ =~ ]]` has incompatible differences between implementations and even between versions for bash and several bugs in some. Personally, I prefer `[`.
–Stéphane Chazelas - Jan 16 '17 at 15:55
