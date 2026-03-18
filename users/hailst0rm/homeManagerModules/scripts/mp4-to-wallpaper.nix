{
  pkgs,
  lib,
  config,
  ...
}: {
  config = lib.mkIf config.scripts.mp4-to-wallpaper.enable {
    home.packages = with pkgs; [
      (writeShellScriptBin "mp4-to-wallpaper" ''
        #!/usr/bin/env bash

        # Colors for output
        RED='\033[0;31m'
        GREEN='\033[0;32m'
        YELLOW='\033[1;33m'
        BLUE='\033[0;34m'
        NC='\033[0m' # No Color

        MODE="copy"  # Default: copy MP4 directly (for mpvpaper)

        # Parse flags
        while [[ "$1" == -* ]]; do
            case "$1" in
                --gif)
                    MODE="gif"
                    shift
                    ;;
                -h|--help)
                    echo -e "Usage: mp4-to-wallpaper [--gif] <input.mp4> [duration] [fps] [resolution]"
                    echo -e ""
                    echo -e "Adds an MP4 video to a wallpaper category."
                    echo -e ""
                    echo -e "Options:"
                    echo -e "  --gif    Convert to GIF (for swww). Default: copy MP4 directly (for mpvpaper)"
                    echo -e ""
                    echo -e "Examples:"
                    echo -e "  mp4-to-wallpaper video.mp4              # Copy MP4 to category (mpvpaper)"
                    echo -e "  mp4-to-wallpaper --gif video.mp4 5 30   # Convert to 5s GIF at 30fps (swww)"
                    exit 0
                    ;;
                *)
                    echo -e "''${RED}Unknown option: $1''${NC}"
                    exit 1
                    ;;
            esac
        done

        # Check if input file is provided
        if [ $# -eq 0 ]; then
            echo -e "''${RED}Error: No input file specified''${NC}"
            echo -e "Usage: mp4-to-wallpaper [--gif] <input.mp4> [duration] [fps] [resolution]"
            exit 1
        fi

        INPUT_FILE="$1"

        # Check if input file exists
        if [ ! -f "$INPUT_FILE" ]; then
            echo -e "''${RED}Error: File '$INPUT_FILE' not found''${NC}"
            exit 1
        fi

        # Wallpaper directory
        WALLPAPER_DIR="${config.nixosDir}/assets/wallpapers"

        # Check if wallpaper directory exists
        if [ ! -d "$WALLPAPER_DIR" ]; then
            echo -e "''${RED}Error: Wallpaper directory not found: $WALLPAPER_DIR''${NC}"
            exit 1
        fi

        # Get available color folders
        echo -e "''${BLUE}Available wallpaper categories:''${NC}"
        CATEGORIES=()
        INDEX=1
        for dir in "$WALLPAPER_DIR"/*/ ; do
            if [ -d "$dir" ]; then
                CATEGORY=$(basename "$dir")
                CATEGORIES+=("$CATEGORY")
                echo -e "  ''${GREEN}[$INDEX]''${NC} $CATEGORY"
                ((INDEX++))
            fi
        done

        # Ask user to select category
        echo -e "\n''${YELLOW}Select category number (or type name):''${NC} "
        read -r SELECTION

        # Determine selected category
        SELECTED_CATEGORY=""
        if [[ "$SELECTION" =~ ^[0-9]+$ ]] && [ "$SELECTION" -ge 1 ] && [ "$SELECTION" -le "''${#CATEGORIES[@]}" ]; then
            SELECTED_CATEGORY="''${CATEGORIES[$((SELECTION-1))]}"
        else
            for category in "''${CATEGORIES[@]}"; do
                if [ "$category" = "$SELECTION" ]; then
                    SELECTED_CATEGORY="$category"
                    break
                fi
            done
        fi

        if [ -z "$SELECTED_CATEGORY" ]; then
            echo -e "''${RED}Error: Invalid selection''${NC}"
            exit 1
        fi

        TARGET_DIR="$WALLPAPER_DIR/$SELECTED_CATEGORY"

        if [ "$MODE" = "copy" ]; then
            # Direct copy for mpvpaper
            BASENAME=$(basename "$INPUT_FILE")
            TARGET_PATH="$TARGET_DIR/$BASENAME"

            echo -e "\n''${BLUE}Copying MP4 to wallpaper directory...''${NC}"
            echo -e "  Input:  $INPUT_FILE"
            echo -e "  Output: $TARGET_PATH"

            if cp "$INPUT_FILE" "$TARGET_PATH"; then
                FILE_SIZE=$(du -h "$TARGET_PATH" | cut -f1)
                echo -e "\n''${GREEN}Successfully copied to:''${NC}"
                echo -e "  $TARGET_PATH"
                echo -e "  Size: $FILE_SIZE"
            else
                echo -e "\n''${RED}Copy failed''${NC}"
                exit 1
            fi
        else
            # GIF conversion for swww
            if ! command -v ffmpeg &> /dev/null; then
                echo -e "''${RED}Error: ffmpeg is not installed''${NC}"
                exit 1
            fi

            DURATION="''${2:-5}"
            FPS="''${3:-30}"
            RESOLUTION="''${4:-3840:2160}"

            BASENAME=$(basename "$INPUT_FILE" .mp4)
            TARGET_PATH="$TARGET_DIR/''${BASENAME}.gif"

            echo -e "\n''${BLUE}Converting MP4 to GIF...''${NC}"
            echo -e "  Input:      $INPUT_FILE"
            echo -e "  Output:     $TARGET_PATH"
            echo -e "  Duration:   ''${DURATION}s"
            echo -e "  FPS:        $FPS"
            echo -e "  Resolution: $RESOLUTION"
            echo ""

            if ${pkgs.ffmpeg_6}/bin/ffmpeg -ss 0 -t "$DURATION" -i "$INPUT_FILE" \
                -vf "fps=$FPS,scale=$RESOLUTION:flags=bicubic" \
                "$TARGET_PATH" 2>&1 | grep -v "^frame="; then
                FILE_SIZE=$(du -h "$TARGET_PATH" | cut -f1)
                echo -e "\n''${GREEN}Successfully converted and saved to:''${NC}"
                echo -e "  $TARGET_PATH"
                echo -e "  Size: $FILE_SIZE"
            else
                echo -e "\n''${RED}Conversion failed''${NC}"
                exit 1
            fi
        fi
      '')
    ];
  };

  options.scripts.mp4-to-wallpaper = {
    enable =
      lib.mkEnableOption "Enable mp4-to-wallpaper script"
      // {
        default = true;
      };
  };
}
