## Create forcing soft links for the NADaymet/TESSFA cases

import os
import glob
import shutil

path = "../atm_forcing.datm7.km.1d"

# Check if the directory exists
if os.path.isdir(path):
    # If it exists, remove it
    shutil.rmtree(path)

# Create a new folder
os.makedirs(path)
# Change to the new directory
os.chdir(path)

# Get a list of all files in the forcing directory and its subdirectories
files = glob.glob('../forcing/**/*', recursive=True)

# Loop through the files
for file in files:
    base = os.path.basename(file)
    # Accept both legacy 'clmforc' and mistaken 'climforc' spellings
    if 'clmforc' in base or 'climforc' in base:
        # Normalize so downstream logic always sees 'clmforc'
        norm_base = base.replace('climforc', 'clmforc')

        # Split the normalized file name on '_'
        parts = norm_base.split('_')

        # Drop the AOI/case prefix when constructing link_name
        if len(parts) > 1:
            link_name = '_'.join(parts[1:])
        else:
            link_name = norm_base

        prefix = "clmforc."
        suffix = ".1d"
        replacement = "Daymet.km"

        # Find the start and end indices for slicing
        start_index = len(prefix)  # Length of "clmforc."
        end_index = link_name.find(suffix)  # Find where ".1d" is located

        # Construct the new link_name
        new_link_name = link_name[:start_index] + replacement + link_name[end_index:]

        # Create a soft link in the target directory
        link_path = os.path.join(path, new_link_name)

        # Only create the link if it does not already exist
        if not os.path.exists(link_path):
            command = f'ln -s "{file}" "{link_path}"'
            print(command)
            os.system(command)
        else:
            print(f"Link {link_path} already exists, skipping.")

files = glob.glob('../domain_surfdata/*')
for file in files:
    print(file)
    # Check if 'domain' is in the file name
    if '_domain.lnd' in file:
        # Construct the new link_name
        new_link_name = "domain.lnd.Daymet.km.1d.nc"
        # Create a soft link in the target directory
        link_path = os.path.join(path, new_link_name)

        # Only create the link if it does not already exist
        if not os.path.exists(link_path):
            command = f'ln -s "{file}" "{link_path}"'
            print(command)
            os.system(command)
        else:
            print(f"Link {link_path} already exists, skipping.")


print("Soft links created successfully.")
