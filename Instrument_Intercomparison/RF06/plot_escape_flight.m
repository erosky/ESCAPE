function out = plot_escape_flight(ncfile)
    %Plot a time series of CDP DSDs from SPICULE
    
    %Get data from the netCDF file
    time = ncread(ncfile,'Time');
    v_wind = ncread(ncfile, 'vwind_rt');
    temp = ncread(ncfile, 'Ts_rt');
    alt = ncread(ncfile,'alt_rt');
    lwc_cdp = ncread(ncfile,'lwc_cdp_sp_rt');
    lwc_nev = ncread(ncfile,'lwc_nevz_sp_rt');
    flightnumber = upper(ncreadatt(ncfile, '/', 'FlightNumber'));
    flightdate = ncreadatt(ncfile, '/', 'FlightDate');

    
    % Reformat time to human readable format
    % Given in netcdf file as seconds since 1970-01-01 +0000
    time2 = datetime(1970,1,1) + seconds(time(:,1));
    
    %Make figure
    figure(1);
    tiledlayout(4,1);
    ax1 = nexttile;
    
    %Altitude
    plot(time2, alt)
    xlabel('Time')
    ylabel('Altitude (meters)')
    grid on

    title([flightnumber ' ' date]);
    
    %Temperature
    ax2 = nexttile;
    plot(time2, temp)
    xlabel('Time')
    ylabel('Static Air Temperature (deg)')
    grid on
    
    %Vertical Wind
    ax3 = nexttile;
    plot(time2, v_wind)
    xlabel('Time')
    ylabel('Vertical Windspeed (m/s)')
    grid on
    
    %LWC
    ax4 = nexttile;
    p4 = plot(time2, lwc_cdp, time2, lwc_nev);
    %p4.DataTipTemplate.DataTipRows(1).Label = 'Time';
    %p4.DataTipTemplate.DataTipRows(1).Format = "HH:mm:ss";
    xticks('auto')
    %ylim([0 2])
    xlabel('Time')
    ylabel('LWC (g/m3)')
    grid on
    
    %Link axes for panning and zooming
    linkaxes([ax1, ax2, ax3, ax4],'x');
    zoom xon;  %Zoom x-axis only
    pan;  %Toggling pan twice seems to trigger desired behavior, not sure why
    pan;
    
end