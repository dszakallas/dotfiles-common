(defconst chatgpt-shell-packages
  '(chatgpt-shell pcsv))

(defun chatgpt-shell/init-chatgpt-shell ()
  (use-package chatgpt-shell
    :ensure t))

(defun chatgpt-shell/init-pcsv ()
  (use-package pcsv
    :ensure t))

(defun chatgpt-shell/post-init-chatgpt-shell ()
  (spacemacs/declare-prefix "ac" "chat")
  (spacemacs/declare-prefix "acX" "send")
  (spacemacs/declare-prefix "acQ" "describe")
  (spacemacs/declare-prefix "acN" "generate")
  (spacemacs/declare-prefix "acC" "compose")
  (spacemacs/set-leader-keys
    "acc" 'chatgpt-shell
    "acq" 'chatgpt-shell-describe-code
    "ace" 'chatgpt-shell-prompt-compose
    "aci" 'chatgpt-shell-quick-insert
    "acm" 'chatgpt-shell-mark-block
    "act" 'chatgpt-shell-generate-unit-test
    "acx" 'chatgpt-shell-send-region
    "acy" 'chatgpt-shell-send-and-review-region

    "acQc" 'chatgpt-shell-describe-code
    "acQi" 'chatgpt-shell-describe-image

    "acNt" 'chatgpt-shell-generate-unit-test

    "acXX" 'chatgpt-shell-send-region
    "acXe" 'chatgpt-shell-send-and-review-region

    "acCC" 'chatgpt-shell-prompt-compose
    "acCm" 'chatgpt-shell-mark-block
    "acCz" 'chatgpt-shell-prompt-compose-swap-system-prompt
    "acCx" 'chatgpt-shell-prompt-compose-send-buffer
    "acCp" 'chatgpt-shell-prompt-compose-previous-item
    "acCP" 'chatgpt-shell-prompt-compose-previous-interaction
    "acCd" 'chatgpt-shell-prompt-compose-cancel)

  (spacemacs/declare-prefix-for-mode 'chatgpt-shell-mode "mC" "configure")
  (spacemacs/declare-prefix-for-mode 'chatgpt-shell-mode "mM" "session")
  (spacemacs/declare-prefix-for-mode 'chatgpt-shell-mode "mX" "submit")
  (spacemacs/declare-prefix-for-mode 'chatgpt-shell-mode "mQ" "describe")
  (spacemacs/declare-prefix-for-mode 'chatgpt-shell-mode "mE" "edit")

  (spacemacs/set-leader-keys-for-major-mode 'chatgpt-shell-mode
    ;; navigation
    "N" 'chatgpt-shell-previous-item
    "n" 'chatgpt-shell-next-item
    "h" 'chatgpt-shell-search-history

    ;; submissions
    "x" 'chatgpt-shell-submit
    "r" 'chatgpt-shell-refactor-code
    "XX" 'chatgpt-shell-submit

    ;; queries
    "Qc" 'chatgpt-shell-describe-code
    "Qe" 'chatgpt-shell-eshell-whats-wrong-with-last-command
    "Qi" 'chatgpt-shell-describe-image

    ;; edits
    "Ec" 'chatgpt-shell-refactor-code

    ;; save / load
    "Ms" 'chatgpt-shell-save-session-transcript
    "Ml" 'chatgpt-shell-restore-session-from-transcript

    ;; settings
    "Cz" 'chatgpt-shell-swap-system-prompt
    "CZ" 'chatgpt-shell-load-awesome-prompts
    "Cm" 'chatgpt-shell-swap-model
    "C1" 'chatgpt-shell-set-as-primary-shell
    "Cr" 'chatgpt-shell-rename-buffer))
