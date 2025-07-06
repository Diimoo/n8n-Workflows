import re
import json

if __name__ == "__main__":
    file_path = "n8n_workflow_reddit_video_automation.json"
    final_content_to_write = None

    try:
        with open(file_path, "r", encoding="utf-8") as f:
            original_content = f.read()

        # Step 1: Remove block comments /* ... */
        content_no_block_comments = re.sub(r'/\*.*?\*/', '', original_content, flags=re.DOTALL)

        # Step 2: Remove line comments //
        lines = content_no_block_comments.splitlines()
        cleaned_lines = []
        for line_content in lines:
            # Remove // comments if they are not inside a string literal.
            # This is a simplified approach: assumes // is not part of a valid string value like a URL.
            # A more robust way would be to find the first non-quoted //
            parts = line_content.split('"')
            new_line = []
            is_outside_quote = True
            for i, part in enumerate(parts):
                if is_outside_quote:
                    # If part contains //, take only stuff before it
                    comment_start_index = part.find('//')
                    if comment_start_index != -1:
                        new_line.append(part[:comment_start_index])
                        break # Rest of the line is a comment
                    else:
                        new_line.append(part)
                else:
                    # This part is inside quotes, add it as is
                    new_line.append(part)

                # Toggle state if this part isn't an escaped quote
                if not (i > 0 and parts[i-1].endswith('\\')):
                    is_outside_quote = not is_outside_quote
            cleaned_lines.append('"'.join(new_line))

        content_no_line_comments = "\n".join(cleaned_lines)

        # Step 3: Remove trailing commas
        content_no_trailing_commas = re.sub(r',\s*([\}\]])', r'\1', content_no_line_comments)

        final_cleaned_content = content_no_trailing_commas

        parsed_json = json.loads(final_cleaned_content)
        final_content_to_write = json.dumps(parsed_json, indent=2) # Pretty print
        print(f"File {file_path} cleaned and successfully parsed.")

    except json.JSONDecodeError as e:
        print(f"JSON parsing failed: {e}")
        error_line = e.lineno
        error_col = e.colno
        problem_lines = final_cleaned_content.splitlines() # Use the state of content that failed
        print(f"Error is around line {error_line}, column {error_col}.")
        if 0 < error_line <= len(problem_lines):
            print("Problematic line content:")
            current_line_content = problem_lines[error_line-1]
            print(f">>>{current_line_content}<<<")
            # Highlight the column
            print(f"   {' ' * (error_col - 1)}^")

            context_start = max(0, error_line - 3)
            context_end = min(len(problem_lines), error_line + 2)
            print("\nContext:")
            for i in range(context_start, context_end):
                prefix = ">> " if i == error_line -1 else "   "
                print(f"{prefix}{i+1}: {problem_lines[i]}")

        final_content_to_write = final_cleaned_content
        print(f"Wrote content that failed parsing to {file_path} for inspection.")
    except FileNotFoundError:
        print(f"Error: File not found at {file_path}")
    except Exception as e:
        print(f"An unexpected error occurred: {e}")

    if final_content_to_write is not None:
        with open(file_path, "w", encoding="utf-8") as f:
            f.write(final_content_to_write)
