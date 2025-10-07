# create TES_AOI_surfdata.nc

import netCDF4 as nc
import numpy as np
from pyproj import Transformer
#import matplotlib.pyplot as plt
from scipy.spatial import cKDTree
import pandas as pd
import sys, os

from datetime import datetime

# Get current date
current_date = datetime.now()
# Format date to mmddyyyy
formatted_date = current_date.strftime('%y%m%d')

def main():
    args = sys.argv[1:]
    # Check the number of arguments
    if len(sys.argv) != 6  or sys.argv[1] == '--help':  # sys.argv includes the script name as the first argument
        print("Example use: python TES_AOI_surfdataGEN.py <input_path> <TES_surfdata> <output_path> <AOI_file_path>  <AOI_points_file>")
        print(" <input_path>: path to the 1D surfdata source data directory")
        print(" <TES_surfdata>: 1D TES_surfdata.nc")
        print(" <output_path>:  path for the 1D AOI surface data directory")
        print(" <AOI_file_path>:  path to the <AOI_points_files>")
        print(" <AOI_points_file>:  <AOI>_gridID.csv or <AOI>_domain.nc")
        print(" The code uses TES surfdata  to generation 1D AOI surfdata")      
        exit(0)
    
    input_path = args[0]
    if not input_path.endswith("/"): input_path=input_path+'/'
    surfdata_file = args[1]
    output_path = args[2]
    if not output_path.endswith("/"): output_path=output_path+'/'
    AOI_gridID_path = args[3]
    AOI_gridID_file = args[4]
    '''
    input_path = '/gpfs/wolf2/cades/cli185/proj-shared/wangd/kiloCraft/NA_surfdataGEN/'
    surfdata_file = 'surfdata.Daymet_NA.1km.1d.c240327.nc'
    output_path = "./temp"
    
    AOI_gridID_path = "./AKSP_info/"
    AOI_gridID_file = 'AKSP_gridID.csv'
    #AOI_gridID_file = 'AKSP_domain.lnd.Daymet_NA.1km.1d.c240403.nc'
    #AOI_gridID_file = 'AKSP_xcyc.csv'
    #AOI_gridID_file = 'AKSP_xcyc_lcc.csv'
    '''
    
    AOI=AOI_gridID_file.split("_")[0]

    # get the full path
    AOI_gridID_file = AOI_gridID_path + AOI_gridID_file

    if (AOI_gridID_file.endswith('gridID.csv')):
        #AOI_gridcell_file = AOI+'_gridID.csv'  # user provided gridcell IDs
        df = pd.read_csv(AOI_gridID_file, sep=",", skiprows=1, names = ['gridID'])
        #read gridIds
        AOI_points = np.array(df['gridID'])
    elif 'domain' in AOI_gridID_file and AOI_gridID_file.endswith('.nc'):
        src = nc.Dataset(AOI_gridID_file, 'r')
        AOI_points = src['gridID'][:]
    else:
        print("Error: Invalid AOI_points_file, see help.")

    # save to the 1D domain file
    
    AOIsurfdata = output_path +'/'+str(AOI)+'_surfdata.TES_SE.4km.1d.NLCD.c'+ formatted_date +'.nc'
    print("AOIsurfdata:" + AOIsurfdata)

    # check if file exists then delete it
    if os.path.exists(AOIsurfdata):
        os.remove(AOIsurfdata)

    source_file = input_path+ surfdata_file

    dst = nc.Dataset(AOIsurfdata, 'w', format='NETCDF3_64BIT')

    # open the 1D domain data
    src = nc.Dataset(source_file, 'r', format='NETCDF3_64BIT')

    # read gridIDs from src file
    TES_gridIDs = src.variables['gridID'][:]
    TES_gridcell_list = list(TES_gridIDs)
    print(TES_gridcell_list[0:5])

    # get the index of AOI_points in the TES_gridcell_list
    domain_idx = np.where(np.in1d(TES_gridcell_list, AOI_points))[0]

    # domain_idx = np.sort(domain_idx).squeeze()
    print("gridID_idx", domain_idx[0:10])

    # Copy the global attributes from the source to the target
    for name in src.ncattrs():
        dst.setncattr(name, src.getncattr(name))

    # Copy the dimensions from the source to the target
    for name, dimension in src.dimensions.items():
        if name != 'gridcell':
            dst.createDimension(
                name, (len(dimension) if not dimension.isunlimited() else None))
        else:
            # Update the 'ni' dimension with the length of the list
            #dst.dimensions['ni'].set_length(len(AOI_points))
            ni = dst.createDimension('gridcell', AOI_points.size)

    count = 0 # record how may 2D layers have been processed 
    
    # Copy the variables from the source to the target
    for name, variable in src.variables.items():

        if (len(variable.dimensions) == 0 or variable.dimensions[-1] != 'gridcell'):
            x = dst.createVariable(name, variable.datatype, variable.dimensions)   
            print(name, variable.dimensions)
            # Copy variable attributes
            dst[name].setncatts(src[name].__dict__)
            # Copy the data
            dst[name][...] = src[name][...]

        else:
            if len(variable.dimensions) == 1:
                x = dst.createVariable(name, variable.datatype, ('gridcell',))   
                print(name, dst[name].dimensions)           
                dst[name][:] = src[name][domain_idx]
            if len(variable.dimensions) == 2:
                x = dst.createVariable(name, variable.datatype, variable.dimensions[:-1]+('gridcell',))   
                print(name, dst[name].dimensions)               
                for index in range(variable.shape[0]):
                    # get all the source data (global)
                    dst[name][index,:] = src[name][index][domain_idx]

                    count = count +1

            if len(variable.dimensions) == 3:
                x = dst.createVariable(name, variable.datatype, variable.dimensions[:-1]+('gridcell',))   
                print(name, dst[name].dimensions)   
                for index1 in range(variable.shape[0]):
                    for index2 in range(variable.shape[1]):
                        # get all the source data (global)
                        dst[name][index1,index2,:] = src[name][index1][index2][domain_idx]
                    print('finished layer#: ' + str(index1))    
                    count = count + variable.shape[1]

            # Copy variable attributes (except _FillValue)
            attrs = dict(src[name].__dict__)
            attrs.pop('_FillValue', None)
            dst[name].setncatts(attrs)

        #if count > 80:
            #dst.close()   # output the variable into a file to save memory

            #dst = nc.Dataset(AOIsurfdata, 'a')

            #count = 0
        
        print(count)

    dst.title = '1D surfdata for '+ AOI +', generated on ' +formatted_date + ' with ' + source_file
       
    # Close the source netCDF file
    src.close()

    # Save the target netCDF file
    dst.close()

if __name__ == '__main__':
    main()
