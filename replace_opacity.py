import os


def replace_with_opacity(project_dir):
    lib_dir = os.path.join(project_dir, "lib")
    backup_root = os.path.join(project_dir, "backups")
    os.makedirs(backup_root, exist_ok=True)

    for root, _, files in os.walk(lib_dir):
        for file in files:
            if file.endswith(".dart"):
                file_path = os.path.join(root, file)

                with open(file_path, "r", encoding="utf-8") as f:
                    content = f.read()

                if ".withOpacity" in content:
                    # create mirrored folder structure inside backups/
                    rel_path = os.path.relpath(file_path, project_dir)
                    backup_path = os.path.join(backup_root, rel_path)
                    os.makedirs(os.path.dirname(backup_path), exist_ok=True)

                    # save untouched original to backup
                    with open(backup_path, "w", encoding="utf-8") as f:
                        f.write(content)

                    # replace and overwrite file
                    new_content = content.replace(".withOpacity", ".o")
                    with open(file_path, "w", encoding="utf-8") as f:
                        f.write(new_content)

                    print(f"✅ Updated: {file_path} (backup at {backup_path})")


if __name__ == "__main__":
    project_directory = os.getcwd()  # current working dir
    replace_with_opacity(project_directory)
    print("🎉 Replacement complete. All backups are in ./backups/lib/")
