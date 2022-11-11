;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;; Place your private configuration here! Remember, you do not need to run 'doom
;; sync' after modifying this file!


;; Some functionality uses this to identify you, e.g. GPG configuration, email
;; clients, file templates and snippets.
(setq
  user-full-name "Roberto Di Remigio Eikås"
  user-mail-address "roberto@totaltrash.xyz")

;; Doom exposes five (optional) variables for controlling fonts in Doom. Here
;; are the three important ones:
;;
;; + `doom-font'
;; + `doom-variable-pitch-font'
;; + `doom-big-font' -- used for `doom-big-font-mode'; use this for
;;   presentations or streaming.
;;
;; They all accept either a font-spec, font string ("Input Mono-12"), or xlfd
;; font string. You generally only need these two:
;; (setq doom-font (font-spec :family "monospace" :size 12 :weight 'semi-light)
;;       doom-variable-pitch-font (font-spec :family "sans" :size 13))
(setq
  doom-font (font-spec :family "Fira Code" :size 16 :weight 'normal :width 'normal)
  doom-variable-pitch-font (font-spec :family "Fira Code")
  doom-big-font (font-spec :family "Fira Code" :size 20))

;; There are two ways to load a theme. Both assume the theme is installed and
;; available. You can either set `doom-theme' or manually load a theme with the
;; `load-theme' function. This is the default:
(setq
  doom-themes-enable-bold t    ; if nil, bold is universally disabled
  doom-themes-enable-italic t) ; if nil, italics is universally disabled
(setq doom-theme 'doom-peacock)
(setq doom-themes-treemacs-theme "doom-colors")
(setq fancy-splash-image "~/.config/doom/ascii-crimson-king.png")

;; If you use `org' and don't want your org files in the default location below,
;; change `org-directory'. It must be set before org loads!
(setq org-directory "~/.org/")
(setq org-contacts-file "~/.org/contacts.org")

;; This determines the style of line numbers in effect. If set to `nil', line
;; numbers are disabled. For relative line numbers, set this to `relative'.
(setq display-line-numbers-type 'relative)


;; Here are some additional functions/macros that could help you configure Doom:
;;
;; - `load!' for loading external *.el files relative to this one
;; - `use-package!' for configuring packages
;; - `after!' for running code after a package has loaded
;; - `add-load-path!' for adding directories to the `load-path', relative to
;;   this file. Emacs searches the `load-path' when you load packages with
;;   `require' or `use-package'.
;; - `map!' for binding new keys
;;
;; To get information about any of these functions/macros, move the cursor over
;; the highlighted symbol at press 'K' (non-evil users must press 'C-c c k').
;; This will open documentation for it, including demos of how they are used.
;;
;; You can also try 'gd' (or 'C-c c d') to jump to their definition and see how
;; they are implemented.

;; Own additions

;; display-time-mode setup
(setq
  display-time-day-and-date t
  display-time-24hr-format t
  display-time-format "%H:%M - %A, %B %e %Y")

;; Use rust-analyzer
(setq rustic-lsp-server 'rust-analyzer)

;; Treemacs set up
(setq treemacs-persist-file "~/.treemacs-persist")

;; LSP setup
;; C/C++: prefer clangd over ccls
(setq lsp-clients-clangd-args '("-j=3"
                                "--background-index"
                                "--clang-tidy"
                                "--completion-style=detailed"
                                "--header-insertion=never"
                                "--header-insertion-decorators=0"))

(after! lsp-clangd (set-lsp-priority! 'clangd 2))

;; configure LSP for remote use
;;(after! lsp-mode
;;  (lsp-register-client
;;   (make-lsp-client :new-connection (lsp-tramp-connection "clangd")
;;                    :major-modes '(c++-mode c-mode)
;;                    :remote? t
;;                    :server-id 'clangd-remote)))

;; use alejandra as Nix formatter
(after! nix-mode (setq nix-nixfmt-bin "alejandra"))

;; TRAMP set up
;; Ratios equal to the default values of these variables of 10240 and 4096
(setq tramp-copy-size-limit 10485760)  ;; 2^20 * 10
(setq tramp-inline-compress-start-size 4194304)  ;; 2^20 * 10 / 2.5

;; magit-delta set up
;;(use-package! magit-delta
;;  :after magit
;;  :config
;;  (setq
;;   magit-delta-delta-args
;;   `("--features" "magit-delta")
;;    magit-delta-default-dark-theme "gruvbox-dark"
;;    magit-delta-default-light-theme "gruvbox-light")
;;  (magit-delta-mode))
