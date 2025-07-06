import json
import json5 # type: ignore
import re

if __name__ == "__main__":
    file_path = "n8n_workflow_reddit_video_automation.json"

    try:
        with open(file_path, "r", encoding="utf-8") as f:
            original_content = f.read()

        # Pre-process to replace Unicode newlines/paragraph separators just in case
        # LS (U+2028) and PS (U+2029) can cause issues.
        processed_content = original_content.replace('\u2028', '\n').replace('\u2029', '\n')

        # Remove trailing commas before json5 parsing, as json5 is strict about them in some contexts
        # although it allows them generally. Standard json does not allow them.
        # This regex removes commas before closing braces or brackets.
        processed_content = re.sub(r',\s*([\}\]])', r'\1', processed_content)

        # Load the content using json5
        data = json5.loads(processed_content)

        # Dump the data using the standard json library
        cleaned_json_output = json.dumps(data, indent=2)

        with open(file_path, "w", encoding="utf-8") as f:
            f.write(cleaned_json_output)

        print(f"File {file_path} successfully processed, comments removed, and validated.")

    except Exception as e:
        print(f"An error occurred: {e}")
        # If json5 fails, print context if it's a json5.JSONDecodeError
        if hasattr(e, 'lineno') and hasattr(e, 'colno') and hasattr(e, 'doc'):
            error_line = e.lineno
            error_col = e.colno
            doc_lines = e.doc.splitlines()
            print(f"Error is around line {error_line}, column {error_col}.")
            if 0 < error_line <= len(doc_lines):
                print("Problematic line content:")
                current_line_content = doc_lines[error_line-1]
                print(f">>>{current_line_content}<<<")
                print(f"   {' ' * (error_col - 1)}^")

                context_start = max(0, error_line - 3)
                context_end = min(len(doc_lines), error_line + 2)
                print("\nContext:")
                for i in range(context_start, context_end):
                    prefix = ">> " if i == error_line -1 else "   "
                    print(f"{prefix}{i+1}: {doc_lines[i]}")
        print("Original file was not modified due to error.")
