function [indices, timestamps] = nc_search(ncfile)
    % Search for cloud passes and other conditions.
    % Outputs list of indices for the cloud pass, as well as the Start and
    % End time of segments in UTC

    % Define LWC threshold for cloud
    LWC_threshold = 0.7; % g/m3
    duration_threshold = 10; % seconds

    %Get data from the netCDF file
    time = ncread(ncfile,'Time');
    conc = ncread(ncfile, 'CCDP_LWOO');
    binsizes = ncreadatt(ncfile, 'CCDP_LWOO', 'CellSizes');
    cdplwc = ncread(ncfile,'PLWCD_LWOO');
    meandiam = ncread(ncfile,'DBARD_LWOO');
    flightnumber = upper(ncreadatt(ncfile, '/', 'FlightNumber'));
    flightdate = ncreadatt(ncfile, '/', 'FlightDate');
   

    % Find logical vector where lwc > threshold
    binaryVector = cdplwc > LWC_threshold;

    % Label each region with a label - an "ID" number.
    [labeledVector, numRegions] = bwlabel(binaryVector);
    % Measure lengths of each region and the indexes
    measurements = regionprops(labeledVector, cdplwc, 'Area', 'PixelValues', 'PixelIdxList');
    % Find regions where the area (length) are 3 or greater and
    % put the values into a cell of a cell array
    indices=[];
    n=1;
    for k = 1 : numRegions
      if measurements(k).Area >= duration_threshold;
        % Area (length) is 3 or greater, so store the values.
        out{n} = measurements(k).PixelValues;
        indices{n} = measurements(k).PixelIdxList;
        n=n+1;
      end
    end
    % Display the regions that meet the criteria:
    %celldisp(out)
    
    for p = 1 : length(indices)
        i_start = indices{p}(1);
        i_end = indices{p}(end);
        s_start = seconds(time(i_start));
        s_end = seconds(time(i_end));
        s_start.Format = 'hh:mm:ss.SSS';
        s_end.Format = 'hh:mm:ss.SSS';
        timestamps{p} = [s_start, s_end];
    end
    


end 
