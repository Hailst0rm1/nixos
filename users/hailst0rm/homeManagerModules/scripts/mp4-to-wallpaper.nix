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

        # Check if ffmpeg is available
        if ! command -v ffmpeg &> /dev/null; then
            echo -e "''${RED}Error: ffmpeg is not installed''${NC}"
            exit 1
        fi

        # Check if input file is provided
        if [ $# -eq 0 ]; then
            echo -e "''${RED}Error: No input file specified''${NC}"
            echo -e "Usage: mp4-to-wallpaper <input.mp4> [duration] [fps] [resolution]"
            echo -e "Example: mp4-to-wallpaper chickens.mp4 5 30 3840:2160"
            exit 1
        fi

        INPUT_FILE="$1"
        DURATION="''${2:-5}"          # Default: 5 seconds
        FPS="''${3:-30}"              # Default: 30 fps
        RESOLUTION="''${4:-3840:2160}" # Default: 4K resolution

        # Check if input file exists
        if [ ! -f "$INPUT_FILE" ]; then
            echo -e "''${RED}Error: File '$INPUT_FILE' not found''${NC}"
            exit 1
        fi

        # Get the base name without extension
        BASENAME=$(basename "$INPUT_FILE" .mp4)
        OUTPUT_FILE="''${BASENAME}.gif"

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
            # Check if typed name exists
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
        TARGET_PATH="$TARGET_DIR/$OUTPUT_FILE"

        echo -e "\n''${BLUE}Converting MP4 to GIF...''${NC}"
        echo -e "  Input:      $INPUT_FILE"
        echo -e "  Output:     $TARGET_PATH"
        echo -e "  Duration:   ''${DURATION}s"
        echo -e "  FPS:        $FPS"
        echo -e "  Resolution: $RESOLUTION"
        echo ""

        # Convert MP4 to GIF using ffmpeg
        if ${pkgs.ffmpeg_6}/bin/ffmpeg -ss 0 -t "$DURATION" -i "$INPUT_FILE" \
            -vf "fps=$FPS,scale=$RESOLUTION:flags=bicubic" \
            "$TARGET_PATH" 2>&1 | grep -v "^frame="; then
            echo -e "\n''${GREEN}✓ Successfully converted and saved to:''${NC}"
            echo -e "  $TARGET_PATH"

            # Show file size
            FILE_SIZE=$(du -h "$TARGET_PATH" | cut -f1)
            echo -e "  Size: $FILE_SIZE"
        else
            echo -e "\n''${RED}✗ Conversion failed''${NC}"
            exit 1
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
