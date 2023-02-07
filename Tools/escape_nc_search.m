function [indices, timestamps] = escape_nc_search(ncfile)
    % Search for cloud passes based on liquid water content.
    % Outputs list of indices for the cloud pass, as well as the Start and
    % End time of segments in UTC
    
    % Setting the duration threshold (in seconds) will limit cloud passes to sections
    % that are above the lwc threshold for the specified duration or
    % longer.

    % Define LWC threshold for cloud
    LWC_threshold = 0.7; % g/m3
    duration_threshold = 10; % seconds

    % Get data from the netCDF file
    time = ncread(ncfile,'Time');
    cdplwc = ncread(ncfile,'lwc_cdp_sp_rt'); % cdp liquid water content
    nevzlwc = ncread(ncfile, 'lwc_nevz_sp_rt'); % nevzerov liquid water content
    nevztwc = ncread(ncfile, 'twc_nevz_sp_rt'); % nevzerov total water content
    
    % Which lwc value to use for the search
    LWC = cdplwc;
   

    % Find logical vector where lwc > threshold
    binaryVector = LWC > LWC_threshold;

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
    celldisp(out)
    
    for p = 1 : length(indices)
        i_start = indices{p}(1);
        i_end = indices{p}(end);
        s_start = datetime(i_start, 'convertfrom', 'posixtime', 'Format', 'MM/dd/yy HH:mm:ss.SSS');
        s_end = datetime(i_end, 'convertfrom', 'posixtime', 'Format', 'MM/dd/yy HH:mm:ss.SSS');
        s_start.Format = 'hh:mm:ss.SSS';
        s_end.Format = 'hh:mm:ss.SSS';
        timestamps{p} = [s_start, s_end];
    end
    


end 
