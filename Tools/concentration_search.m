function [indices, timestamps] = concentration_search(ncfile)

    % Use the nc_search function to get a list of start and stop times for
    % cloud passes.
    % Then, check those passes to see if the CDP shows a high concentration
    % of droplets larger than the threshold
    
    % Define large droplet concentration threshold
    Bin = 9; % lower limit bin index
    Conc_threshold = 50.0; % #/cc/um

    [i, t] = nc_search(ncfile);
    
    %Get data from the netCDF file
    time = ncread(ncfile,'Time');
    conc = ncread(ncfile, 'CCDP_LWOO');
    binsizes = ncreadatt(ncfile, 'CCDP_LWOO', 'CellSizes');
    cdplwc = ncread(ncfile,'PLWCD_LWOO');
    meandiam = ncread(ncfile,'DBARD_LWOO');
    flightnumber = upper(ncreadatt(ncfile, '/', 'FlightNumber'));
    flightdate = ncreadatt(ncfile, '/', 'FlightDate');
    
    %Reshape the concentration array into two dimensions
    s = size(conc);
    conc2 = reshape(conc, [s(1), s(3)]);
    size(conc2,1)
    size(binsizes)
    disp(binsizes)
    
    for p = 1 : length(i)
        conc_check = conc2(9:)
    end