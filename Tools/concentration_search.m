function [output_data] = concentration_search(cdp_ncfile)

    % Use the nc_search function to get a list of start and stop times for
    % cloud passes.
    % Then, check those passes to see if the CDP shows a high concentration
    % of droplets larger than the threshold
    
    % Define large droplet concentration threshold
    % 9 = 10.5 um
    % 13 = 15 um
    % 15 = 19 um
    Bin = 13; % lower limit bin index
    Conc_threshold = 50.0; % #/cc/um
    
    LWC_threshold = 0.1;
    cloud_time_threshold = 3;

    [i, t, utc] = cdp_nc_search(cdp_ncfile,LWC_threshold,cloud_time_threshold);
    
    %Get data from the netCDF file
    time = ncread(cdp_ncfile,'time');
    conc = ncread(cdp_ncfile, 'PSD');
    binsizes = ncread(cdp_ncfile, 'bins')
    cdplwc = ncread(cdp_ncfile,'LWC');
    meandiam = ncread(cdp_ncfile,'MVD');
    flightnumber = upper(ncreadatt(cdp_ncfile, '/', 'NRCFlightNumber'));
    flightdate = ncreadatt(cdp_ncfile, '/', 'FlightDate');

    
    %Reshape the concentration array into two dimensions
    s = size(conc);
    conc2 = transpose(conc);
    s2 = size(conc2)
    
    %Convert from L to cc
    conc2 = conc2./1000;
    
    % Final data table to wite to csv
    output_data = table('Size',[0 9],...
                        'VariableTypes',{'datetime','datetime','int8','double','double','double','double','double','double'},...
                        'VariableNames', ["StartTime", "EndTime", "Duration_s", "StartTime_datenum", "EndTime_datenum", "LargeConc_cc", "SmallConc_cc", "MeanDiameter_um", "AverageLWC_g_m3"]);
    
    
    for p = 1 : length(i)
    %    conc_check = conc2(9:end)
        large_conc_array = conc2(Bin:end, i{p}(1):i{p}(end));
        small_conc_array = conc2(1:Bin-1, i{p}(1):i{p}(end));
        % create vector that is the average concentration across cloudpass
        large_conc_avg = mean(large_conc_array,2);
        small_conc_avg = mean(small_conc_array,2);
        % intagrate over small and large to get conc for each
        large_conc = sum(large_conc_avg);
        small_conc =sum(small_conc_avg);
        % average mean diameter
        avg_diam = mean(meandiam(i{p}(1):i{p}(end)));
        % average total LWC
        avg_lwc = mean(cdplwc(i{p}(1):i{p}(end)));
        
        if large_conc > Conc_threshold;
           data = {utc{p}(1), utc{p}(2), length(i{p}), t{p}(1), t{p}(2), large_conc, small_conc, avg_diam, avg_lwc};
           output_data = [output_data;data];
        end

    end
    
    rf_txt = split(flightnumber, "-");
    lwc_txt = split(num2str(LWC_threshold), ".");
    output_filename = sprintf('cloudpasses_%s_%sp%slwc_%02dsec.csv', rf_txt{2}, lwc_txt{1}, lwc_txt{2}, cloud_time_threshold)
    writetable(output_data, "../Case_Studies/CloudPassSearchResults/"+output_filename);