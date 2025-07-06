def inspect_problematic_lines(filepath, error_lineno, num_context_lines=5):
    try:
        with open(filepath, "rb") as f: # Read as binary
            lines_bytes = f.readlines()

        start_line_idx = max(0, error_lineno - 1 - num_context_lines)
        end_line_idx = min(len(lines_bytes), error_lineno + num_context_lines)

        print(f"Inspecting lines {start_line_idx + 1} to {end_line_idx} from {filepath}")

        for i in range(start_line_idx, end_line_idx):
            line_bytes = lines_bytes[i]
            line_str_lossy = line_bytes.decode('utf-8', 'replace') # Show as string

            hex_representation = " ".join(f"{byte:02x}" for byte in line_bytes)

            print(f"\nLine {i+1}:")
            print(f"  String (lossy): {line_str_lossy.rstrip()}")
            print(f"  Bytes (hex):    {hex_representation}")

    except FileNotFoundError:
        print(f"Error: File not found at {filepath}")
    except Exception as e:
        print(f"An unexpected error occurred: {e}")

if __name__ == "__main__":
    # The error was reported at line 382 by json5
    inspect_problematic_lines("n8n_workflow_reddit_video_automation.json", 382, num_context_lines=4)
