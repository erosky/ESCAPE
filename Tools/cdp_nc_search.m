function [indices, timestamps_datenum, timestamps_UTC] = cdp_nc_search(cdp_ncfile, lwc_thresh, cloudtime)
    % Search for cloud passes based on liquid water content.
    % Outputs list of indices for the cloud pass, as well as the Start and
    % End time of segments in UTC
    
    % Setting the duration threshold (in seconds) will limit cloud passes to sections
    % that are above the lwc threshold for the specified duration or
    % longer.

    % Define LWC threshold for cloud
    LWC_threshold = lwc_thresh; % g/m3
    duration_threshold = cloudtime; % seconds

    %Get data from the netCDF file
    time = ncread(cdp_ncfile,'time');
    cdplwc = ncread(cdp_ncfile,'LWC');
    meandiam = ncread(cdp_ncfile,'MVD');
    flightnumber = upper(ncreadatt(cdp_ncfile, '/', 'NRCFlightNumber'));
    flightdate = ncreadatt(cdp_ncfile, '/', 'FlightDate');
    
    % Reformat time to human readable format
    % Given in netcdf file as seconds since 1970-01-01 +0000
    time2 = datetime(1970,1,1) + seconds(time(:,1));
    
    LWC = cdplwc;
   

    % Find logical vector where lwc > threshold
    binaryVector = (LWC > LWC_threshold) & (~isinf(LWC));

    % Label each region with a label - an "ID" number.
    [labeledVector, numRegions] = bwlabel(binaryVector);
    % Measure lengths of each region and the indexes
    measurements = regionprops(labeledVector, LWC, 'Area', 'PixelValues', 'PixelIdxList');
    % Find regions where the area (length) are 3 or greater and
    % put the values into a cell of a cell array
    indices=[];
    n=1;
    for k = 1 : numRegions
      if measurements(k).Area >= duration_threshold;
        % Area (length) is duration_threshold or greater, so store the values.
        out{n} = measurements(k).PixelValues;
        indices{n} = measurements(k).PixelIdxList;
        n=n+1;
      end
    end
    % Display the regions that meet the criteria:
    celldisp(out);
    
    for p = 1 : length(indices)
        i_start = indices{p}(1);
        i_end = indices{p}(end);
        start_time = time(i_start);
        end_time = time(i_end);
        s_start = datetime(start_time, 'convertfrom', 'posixtime', 'Format', 'MM/dd/yy HH:mm:ss.SSS');
        s_end = datetime(end_time, 'convertfrom', 'posixtime', 'Format', 'MM/dd/yy HH:mm:ss.SSS');
        %s_start.Format = 'HH:mm:ss.SSS';
        %s_end.Format = 'HH:mm:ss.SSS';
        timestamps_UTC{p} = [s_start, s_end];
        timestamps_datenum{p} = [datenum(time2(i_start)), datenum(time2(i_end))];
    end
    


end 
