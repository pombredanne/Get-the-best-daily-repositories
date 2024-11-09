# compile-angel.el - Byte-compile and native-compile Emacs Lisp libraries Automatically
![Build Status](https://github.com/jamescherti/compile-angel.el/actions/workflows/ci.yml/badge.svg)
![License](https://img.shields.io/github/license/jamescherti/compile-angel.el)
![](https://raw.githubusercontent.com/jamescherti/compile-angel.el/main/.images/made-for-gnu-emacs.svg)

The **compile-angel** package automatically byte-compiles and native-compiles Emacs Lisp libraries. It offers two global minor modes:
- `(compile-angel-on-save-mode)`: Compiles when an .el file is modified and saved.
- `(compile-angel-on-load-mode)`: Compiles an .el file before it is loaded.

These modes speed up Emacs by ensuring all libraries are byte-compiled and native-compiled. Byte-compilation reduces the overhead of loading Emacs Lisp code at runtime, while native compilation optimizes performance by generating machine code specific to your system.

NOTE: It is recommended to set `load-prefer-newer` to `t`, ensuring that Emacs loads the most recent version of byte-compiled or source files. Additionally, ensure that native compilation is enabled; this should return t: `(native-comp-available-p)`.

## What is the difference between auto-compile and compile-angel?

This package is an alternative to the auto-compile Emacs package. Here are the main differences:
- **Compile-angel ensures more .el files are compiled**: The compile-angel package, in addition to compiling the elisp files that are loaded using `load` and `require`, **also handles files that auto-compile misses**, such as packages that are deferred (e.g., `:defer t` in `use-package`) and the `use-package` dependencies using, for example,`:after package-name`.
- Excluding files from compilation using regular expressions in `compile-angel-excluded-files-regexps`.

*(Special thanks to Jonas Bernoulli, the creator of the auto-compile package, whose work inspired the development of compile-angel. This package was created to offer a lightweight alternative to auto-compile that also compiles deferred/autoloaded .el files.)*

## Features

## Installation

### Install using straight

To install `compile-angel` using `straight.el`:

1. It if hasn't already been done, [add the straight.el bootstrap code](https://github.com/radian-software/straight.el?tab=readme-ov-file#getting-started) to your init file.
2. Add the following code **at the very beginning of your Emacs init file, before anything else**:
```emacs-lisp
(use-package compile-angel
  :ensure t
  :demand t
  :straight (compile-angel
             :type git
             :host github
             :repo "jamescherti/compile-angel.el")
  :config
  (compile-angel-on-save-mode)
  (compile-angel-on-load-mode))
```

## Customizations

``` emacs-lisp
;; Enable/Disable byte compilation and native compilation
(setq compile-angel-enable-byte-compile t)
(setq compile-angel-enable-native-compile t)

;; Enable verbose (Set it to t while debugging)
(setq compile-angel-verbose nil)

;; Display the *Compile-Log* buffer (Set it to t while writing elisp)
(setq compile-angel-display-buffer nil)

;; Perform byte/native compilation of .el files only once during initial loading
;; (Setting this to nil will try to compile each time an .el file is loaded)
(setq compile-angel-on-load-mode-compile-once t)

;; Ignore certain files, for example, for users of the `dir-config` package:
(setq compile-angel-excluded-files-regexps '("/\\.dir-config\\.el$"))

;; Function that determines if an .el file should be compiled. It takes one
;; argument (an EL file) and returns t if the file should be compiled,
;; (By default, `compile-angel-predicate-function` is set to nil, which
;; means that the predicate function is not called.)
(setq compile-angel-predicate-function
   #'(lambda(el-file)
       ;; Show a message
       (message "PREDICATE: %s" el-file)
       ;; Return t (Compile all)
       t))
```

## Author and License

The `compile-angel` Emacs package has been written by [James Cherti](https://www.jamescherti.com/) and is distributed under terms of the GNU General Public License version 3, or, at your choice, any later version.

Copyright (C) 2024 James Cherti

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version. This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details. You should have received a copy of the GNU General Public License along with this program.

## Links

- [compile-angel.el @GitHub](https://github.com/jamescherti/compile-angel.el)
- If users who prefer compiling .el files from the command line: [elispcomp](https://github.com/jamescherti/elispcomp)

Other Emacs packages by the same author:
- [minimal-emacs.d](https://github.com/jamescherti/minimal-emacs.d): This repository hosts a minimal Emacs configuration designed to serve as a foundation for your vanilla Emacs setup and provide a solid base for an enhanced Emacs experience.
- [outline-indent.el](https://github.com/jamescherti/outline-indent.el): An Emacs package that provides a minor mode that enables code folding and outlining based on indentation levels for various indentation-based text files, such as YAML, Python, and other indented text files.
- [vim-tab-bar.el](https://github.com/jamescherti/vim-tab-bar.el): Make the Emacs tab-bar Look Like Vim’s Tab Bar.
- [easysession.el](https://github.com/jamescherti/easysession.el): Easysession is lightweight Emacs session manager that can persist and restore file editing buffers, indirect buffers/clones, Dired buffers, the tab-bar, and the Emacs frames (with or without the Emacs frames size, width, and height).
- [elispcomp](https://github.com/jamescherti/elispcomp): A command line tool that allows compiling Elisp code directly from the terminal or from a shell script. It facilitates the generation of optimized .elc (byte-compiled) and .eln (native-compiled) files.
- [tomorrow-night-deepblue-theme.el](https://github.com/jamescherti/tomorrow-night-deepblue-theme.el): The Tomorrow Night Deepblue Emacs theme is a beautiful deep blue variant of the Tomorrow Night theme, which is renowned for its elegant color palette that is pleasing to the eyes. It features a deep blue background color that creates a calming atmosphere. The theme is also a great choice for those who miss the blue themes that were trendy a few years ago.
- [Ultyas](https://github.com/jamescherti/ultyas/): A command-line tool designed to simplify the process of converting code snippets from UltiSnips to YASnippet format.
- [dir-config.el](https://github.com/jamescherti/dir-config.el): Automatically find and evaluate .dir-config.el Elisp files to configure directory-specific settings.
- [flymake-bashate.el](https://github.com/jamescherti/flymake-bashate.el): A package that provides a Flymake backend for the bashate Bash script style checker.
- [flymake-ansible-lint.el](https://github.com/jamescherti/flymake-ansible-lint.el): An Emacs package that offers a Flymake backend for `ansible-lint`.
