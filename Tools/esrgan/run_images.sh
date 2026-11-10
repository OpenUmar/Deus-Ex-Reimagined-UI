cd "$(dirname "$0")"
ESR_MODEL=x4plus python3 esrgan.py "$HOME/esr_orig" "$HOME/esr_images" '.' > "$HOME/esr_images.log" 2>&1
echo ALLDONE >> "$HOME/esr_images.log"
