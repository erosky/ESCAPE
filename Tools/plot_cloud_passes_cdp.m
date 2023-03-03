function out = plot_cdp_escape(ncfile)
    %Plot a time series of CDP DSDs from SPICULE
    
    %Get data from the netCDF file
    time = ncread(ncfile,'time');
    conc = ncread(ncfile, 'PSD');
    binsizes = ncread(ncfile, 'bins');
    cdplwc = ncread(ncfile,'LWC');
    meandiam = ncread(ncfile,'MVD');
    flightnumber = upper(ncreadatt(ncfile, '/', 'NRCFlightNumber'));
    flightdate = ncreadatt(ncfile, '/', 'FlightDate');

    
    %Reshape the concentration array into two dimensions
    s = size(conc);
    conc2 = transpose(conc);
    s2 = size(conc2);
    
    % Reformat time to human readable format
    % Given in netcdf file as seconds since 1970-01-01 +0000
    time2 = datetime(1970,1,1) + seconds(time(:,1));
    
    %Make figure
    figure(1);
    tiledlayout(4,1);
    ax1 = nexttile([2 1]);
    
    %Concentration contour
    levels = 10.^(linspace(0,4,20));  %Log10 levels
    contourf(datenum(time2), binsizes, conc2, levels, 'LineStyle', 'none');
    datetick('x')
    set(gca,'ColorScale','log');
    grid on

    xlabel('Time')
    ylabel('Diameter (microns)');
    c=colorbar;
    set(gca,'ColorScale','log');
    c.Label.String = 'Concentration (#/cc/um)';
    title([flightnumber ' ' date]);
    
    %Mean Diameter
    ax2 = nexttile;
    plot(datenum(time2), meandiam)
    datetick('x')
    ylim([0 50])
    xlabel('Time')
    ylabel('Dbar (microns)')
    grid on
    
    %LWC
    ax3 = nexttile;
    plot(datenum(time2), cdplwc)
    datetick('x')
    ylim([0 2])
    xlabel('Time')
    ylabel('LWC (g/m3)')
    grid on
    
    %Link axes for panning and zooming
    linkaxes([ax1, ax2, ax3],'x');
    zoom xon;  %Zoom x-axis only
    pan;  %Toggling pan twice seems to trigger desired behavior, not sure why
    pan;
    
end