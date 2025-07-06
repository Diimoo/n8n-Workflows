import json

def parse_json_file(file_path):
    with open(file_path, "r") as f:
        content = f.read()

    try:
        json.loads(content)
        print("JSON parsed successfully!")
    except json.JSONDecodeError as e:
        print(f"JSON parsing failed: {e}")

if __name__ == "__main__":
    parse_json_file("n8n_workflow_reddit_video_automation.json")
