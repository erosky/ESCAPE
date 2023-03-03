function out = manually_filter_cloudpasses(cloudpassfile, ncfile, cdp_ncfile)
    % Plot a snapshot of cloudpasses of interest
    % manually accept or reject them
    % store data for the accepted passes
    
    %Get data from the aircraft netCDF file
    time = ncread(ncfile,'Time');
    cdplwc = ncread(ncfile,'lwc_cdp_sp_rt'); % cdp liquid water content
    nevzlwc = ncread(ncfile, 'lwc_nevz_sp_rt'); % nevzerov liquid water content
    nevztwc = ncread(ncfile, 'twc_nevz_sp_rt'); % nevzerov total water content
    temp = ncread(ncfile,'Ts_rt'); % Static Air Temperature from Rosemount 102 TAT probe on port underwing, in units of degrees Celsius
    vwind = ncread(ncfile,'vwind_rt'); %Vertical windspeed derived from Rosemount 858 airdata probe located on the starboard pylon, in units of metres per second
    
    
    % Reformat time to human readable format
    % Given in netcdf file as seconds since 1970-01-01 +0000
    time2 = datetime(1970,1,1) + seconds(time(:,1));
    
    %Get data from the CDP netCDF file
    time_cdp = ncread(cdp_ncfile,'time');
    conc = ncread(cdp_ncfile, 'PSD');
    binsizes = ncread(cdp_ncfile, 'bins');
    flightnumber = upper(ncreadatt(cdp_ncfile, '/', 'NRCFlightNumber'));
    flightdate = ncreadatt(cdp_ncfile, '/', 'FlightDate');

    time2_cdp = datetime(1970,1,1) + seconds(time_cdp(:,1));
    
    %Reshape the concentration array into two dimensions
    s = size(conc);
    conc2 = transpose(conc);
    s2 = size(conc2);
   
    % Open up the cloudpass file
    passes = readtable(cloudpassfile);
    
    % Check each cloudpass
    % Plot snapshot of cdp dsd, lwc, and vertical wind
    % ask use if they want to keep or reject the cloudpass
    
end