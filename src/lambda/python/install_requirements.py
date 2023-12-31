import os
import subprocess

def install_requirements(directory):
    requirements_path = os.path.join(directory, 'requirements.txt')
    
    # Check if requirements.txt exists in the directory
    if os.path.exists(requirements_path):
        print(f"Installing requirements in {directory}")
        
        # Run pip install -r requirements.txt -t .
        subprocess.run(['pip', 'install', '-r', requirements_path, '-t', directory])
        
        print(f"Requirements installed in {directory}")
    else:
        print(f"No requirements.txt found in {directory}")

def install_requirements_in_subdirectories():
    # Get the current working directory
    current_directory = os.getcwd()

    # Get a list of all subdirectories
    subdirectories = [d for d in os.listdir(current_directory) if os.path.isdir(d)]

    # Install requirements in each subdirectory
    for subdir in subdirectories:
        subdir_path = os.path.join(current_directory, subdir)
        install_requirements(subdir_path)

if __name__ == "__main__":
    install_requirements_in_subdirectories()
