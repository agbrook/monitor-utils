#!/usr/bin/env perl

#####################################
#####################################
### ______               _     =) ###
### | ___ \             | |       ###
### | |_/ / __ _  _ __  | |       ###
### |    / / _` || '_ \ | |       ###
### | |\ \| (_| || | | || |____   ###
### \_| \_|\__,_||_| |_|\_____/   ###
#####################################
#####################################
## Original version written by 
## ran.leibman@gmail.com
## Additionial checks code written
## by laurent.dufour@havas.com
##
## the following parameters has
## been tested against a PA5050
##
## cpu|firmware|ha|model|
## sessions|udp_sessions|tcp_sessions
## |icmp_sessions
##
#####################################
#####################################


use strict;
use lib "/usr/lib/nagios/plugins/";
use Net::SNMP qw(:snmp);
use Getopt::Long qw(:config no_ignore_case);
my $stat;
my $msg;
my $perf;
my $script_name = "check-paloalto-A500.pl";
my $script_version = 1.2;

### SNMP OIDs
###############
my $s_cpu_mgmt = '.1.3.6.1.2.1.25.3.3.1.2.1';
my $s_cpu_data = '.1.3.6.1.2.1.25.3.3.1.2.2';
my $s_firmware = '.1.3.6.1.2.1.25.3.3.1.2.2';
my $s_firmware_version = '.1.3.6.1.4.1.25461.2.1.2.1.1.0';
my $s_ha_mode = '.1.3.6.1.4.1.25461.2.1.2.1.13.0';
my $s_ha_local_state = '.1.3.6.1.4.1.25461.2.1.2.1.11.0';
my $s_ha_peer_state = '.1.3.6.1.4.1.25461.2.1.2.1.12.0';
my $s_pa_model = '.1.3.6.1.4.1.25461.2.1.2.2.1.0';
my $s_pa_max_sessions = '.1.3.6.1.4.1.25461.2.1.2.3.2.0';
my $s_pa_total_active_sessions = '.1.3.6.1.4.1.25461.2.1.2.3.3.0';
my $s_pa_total_tcp_active_sessions = '.1.3.6.1.4.1.25461.2.1.2.3.4.0';
my $s_pa_total_udp_active_sessions = '.1.3.6.1.4.1.25461.2.1.2.3.5.0';
my $s_pa_total_icmp_active_sessions = '.1.3.6.1.4.1.25461.2.1.2.3.6.0';

### Storage OIDs
my $s_storageTable = '.1.3.6.1.2.1.25.2.3';
my $s_storageTable_memory_size = '1.3.6.1.2.1.25.2.3.1.5.20';
my $s_storageTable_memory_used = '1.3.6.1.2.1.25.2.3.1.6.20';
my $s_storageTable_swap_size = '1.3.6.1.2.1.25.2.3.1.5.30';
my $s_storageTable_swap_used = '1.3.6.1.2.1.25.2.3.1.6.30';
my $s_storageTable_config_part_size = '1.3.6.1.2.1.25.2.3.1.5.40';
my $s_storageTable_config_part_used = '1.3.6.1.2.1.25.2.3.1.6.40';
my $s_storageTable_log_part_size = '1.3.6.1.2.1.25.2.3.1.5.41';
my $s_storageTable_log_part_used = '1.3.6.1.2.1.25.2.3.1.6.41';
my $s_storageTable_root_part_size = '1.3.6.1.2.1.25.2.3.1.5.42';
my $s_storageTable_root_part_used = '1.3.6.1.2.1.25.2.3.1.6.42';

### Functions
###############
sub _create_session {
    my ($server, $comm) = @_;
    my $snmp_version = 2;
    my ($sess, $err) = Net::SNMP->session( -hostname => $server, -version => $snmp_version, -community => $comm);
    if (!defined($sess)) {
	print "Can't create SNMP session to $server\n";
	exit(1);
    }
    return $sess;
}

sub FSyntaxError {
    print "Syntax Error !\n";
    print "$script_name\n";
    print "Version : $script_version\n";
    print "-H = Ip/Dns Name of the FW\n";
    print "-C = SNMP Community\n";
    print "-t = Check type (currently only cpu/firmware/model/ha/sessions/icmp_sesions/tcp_sessions/udp_sessions/memory/swap/config_part/log_part/root_part/interface)\n";
    print "-w = Warning Value (not needed for firmware, model or ha type)\n";
    print "-c = Critical Value (not needed for firmware, model or ha type)\n";
    exit(3);
}


### Gather input from user
#############################
my $switch;# = $options{'H'};
my $community;# = $options{'C'};
my $check_type;# = $options{'t'};
my $warn = 0; #$options{'w'} || 0;
my $crit = 0; #$options{'c'} || 0;
GetOptions(
    "switch|H=s" => \$switch,
    "community|C=s" => \$community,
    "check_type|t=s" => \$check_type,
    "warn|w=i" => \$warn,
    "critical|c=i" => \$crit,

);

# Validate IP or hostname is passed in
if (!$switch) {
    print "IP or Hostname of the FW missing\n";
    FSyntaxError();
}
# Validdate that a community string is passed in
if(!$community) {
    print "Community string missing\n";
    FSyntaxError();
}
# Validate Warning
if($warn > $crit) {
    print "Warning can't be larger then Critical: $warn > $crit\n";
    FSyntaxError();
}

# Establish SNMP Session
our $snmp_session = _create_session($switch,$community);


### model ###
if($check_type eq "model") {
    my $R_firm = $snmp_session->get_request(-varbindlist => [$s_pa_model]);
    my $palo_model = "$R_firm->{$s_pa_model}";


    $msg = "OK: Palo Alto  $palo_model";
    $perf="";
    $stat = 0;
}

### HA MODE ###
elsif($check_type eq "ha") {
    my $R_firm = $snmp_session->get_request(-varbindlist => [$s_ha_mode]);
    my $ha_mode = "$R_firm->{$s_ha_mode}";

    my $R_firm = $snmp_session->get_request(-varbindlist => [$s_ha_local_state]);
    my $ha_local_state = "$R_firm->{$s_ha_local_state}";

    my $R_firm = $snmp_session->get_request(-varbindlist => [$s_ha_peer_state]);
    my $ha_peer_state = "$R_firm->{$s_ha_peer_state}";


    $msg =  "OK: High Availablity Mode :  $ha_mode - Local :  $ha_local_state - Peer  :  $ha_peer_state\n";
    $perf="";
    $stat = 0;
}


### SESSIONS ###
elsif($check_type eq "sessions" and $warn and $crit) {
    my $R_firm = $snmp_session->get_request(-varbindlist => [$s_pa_max_sessions]);
    my $pa_max_sessions = "$R_firm->{$s_pa_max_sessions}";

    my $R_firm = $snmp_session->get_request(-varbindlist => [$s_pa_total_active_sessions]);
    my $pa_total_active_sessions = "$R_firm->{$s_pa_total_active_sessions}";

	$perf=" - Max Active Sessions :  $pa_max_sessions";
    
    if($pa_total_active_sessions > $crit ) {
	$msg =  "CRIT: Total Active Sessions :  $pa_total_active_sessions".$perf;
	$stat = 2;
    } elsif($pa_total_active_sessions > $warn ) {
	$msg =  "WARN: Total Active Sessions :  $pa_total_active_sessions".$perf;
	$stat = 1;
    } else {
	$msg =  "OK:   Total Active Sessions :  $pa_total_active_sessions".$perf;
	$stat = 0;

    }

    $perf = "active=$pa_total_active_sessions:$warn:$crit";

}

### TCP SESSIONS ###
elsif($check_type eq "tcp_sessions" and $warn and $crit) {
    my $R_firm = $snmp_session->get_request(-varbindlist => [$s_pa_total_tcp_active_sessions]);
    my $pa_total_tcp_active_sessions = "$R_firm->{$s_pa_total_tcp_active_sessions}";

    
    if($pa_total_tcp_active_sessions > $crit ) {
	$msg =  "CRIT: TCP Active Sessions :  $pa_total_tcp_active_sessions";
	$stat = 2;
    } elsif($pa_total_tcp_active_sessions > $warn ) {
	$msg =  "WARN: TCP Active Sessions :  $pa_total_tcp_active_sessions";
	$stat = 1;
    } else {
	$msg =  "OK:   TCP Active Sessions :  $pa_total_tcp_active_sessions";
	$stat = 0;

    }

    $perf = "active=$pa_total_tcp_active_sessions:$warn:$crit";

}

### UDP SESSIONS ###
elsif($check_type eq "udp_sessions" and $warn and $crit) {
    my $R_firm = $snmp_session->get_request(-varbindlist => [$s_pa_total_udp_active_sessions]);
    my $pa_total_udp_active_sessions = "$R_firm->{$s_pa_total_udp_active_sessions}";

    
    if($pa_total_udp_active_sessions > $crit ) {
	$msg =  "CRIT: UDP Active Sessions :  $pa_total_udp_active_sessions";
	$stat = 2;
    } elsif($pa_total_udp_active_sessions > $warn ) {
	$msg =  "WARN: UDP Active Sessions :  $pa_total_udp_active_sessions";
	$stat = 1;
    } else {
	$msg =  "OK:   UDP Active Sessions :  $pa_total_udp_active_sessions";
	$stat = 0;

    }

    $perf = "active=$pa_total_udp_active_sessions:$warn:$crit";

}

### ICMP SESSIONS ###
elsif($check_type eq "icmp_sessions" and $warn and $crit) {
    my $R_firm = $snmp_session->get_request(-varbindlist => [$s_pa_total_icmp_active_sessions]);
    my $pa_total_icmp_active_sessions = "$R_firm->{$s_pa_total_icmp_active_sessions}";

    
    if($pa_total_icmp_active_sessions > $crit ) {
	$msg =  "CRIT: ICMP Active Sessions :  $pa_total_icmp_active_sessions";
	$stat = 2;
    } elsif($pa_total_icmp_active_sessions > $warn ) {
	$msg =  "WARN: ICMP Active Sessions :  $pa_total_icmp_active_sessions";
	$stat = 1;
    } else {
	$msg =  "OK:   ICMP Active Sessions :  $pa_total_icmp_active_sessions";
	$stat = 0;

    }

    $perf = "active=$pa_total_icmp_active_sessions:$warn:$crit";

}

### firmware ###
elsif($check_type eq "firmware") {
    my $R_firm = $snmp_session->get_request(-varbindlist => [$s_firmware_version]);
    my $palo_os_ver = "$R_firm->{$s_firmware_version}";


    $msg = "OK: Firmware $palo_os_ver";
    $perf="";
    $stat = 0;
}

### CPU ###
elsif($check_type eq "cpu" and $warn and $crit) {
    my $R_mgmt = $snmp_session->get_request(-varbindlist => [$s_cpu_mgmt]);
    my $mgmt = "$R_mgmt->{$s_cpu_mgmt}";
    my $R_data = $snmp_session->get_request(-varbindlist => [$s_cpu_data]);
    my $data = "$R_data->{$s_cpu_data}";

    if($mgmt > $crit or $data > $crit) {
	$msg = "CRIT: Mgmt - $mgmt, Data - $data";
	$stat = 2;
    } elsif($mgmt > $warn or $data > $warn) {
	$msg = "WARN: Mgmt - $mgmt, Data - $data";
	$stat = 1;
    } else {
	$msg = "OK: Mgmt - $mgmt, Data - $data";
	$stat = 0;
    }
    $perf = "mgmt=$mgmt:$warn:$crit;data=$data;$warn;$crit";
} 
### Memory Check ###
elsif($check_type eq "memory" and $warn and $crit) {
    my $memory_used = ($snmp_session->get_request(-varbindlist => [$s_storageTable_memory_used]))->{$s_storageTable_memory_used};
    my $memory_size = ($snmp_session->get_request(-varbindlist => [$s_storageTable_memory_size]))->{$s_storageTable_memory_size};
    my $memory_perc = sprintf "%.2f", ($memory_used/$memory_size)*100;

    if($memory_perc > $crit) {
        $msg = "CRIT: ";
        $stat = 2;
    } elsif ($memory_perc > $warn) {
        $msg = "WARN: ";
        $stat = 1;
    } else {
        $msg = "OK: ";
        $stat = 1;
    }
    $msg = $msg ."Memory Used Percent - $memory_perc";
    $perf = "memory=$memory_perc:$warn:$crit";
}
### Swap Check ###
elsif($check_type eq "swap" and $warn and $crit) {
    my $swap_used = ($snmp_session->get_request(-varbindlist => [$s_storageTable_swap_used]))->{$s_storageTable_swap_used};
    my $swap_size = ($snmp_session->get_request(-varbindlist => [$s_storageTable_swap_size]))->{$s_storageTable_swap_size};
    my $swap_perc = sprintf "%.2f", ($swap_used/$swap_size)*100;

    if($swap_perc > $crit) {
        $msg = "CRIT: ";
        $stat = 2;
    } elsif ($swap_perc > $warn) {
        $msg = "WARN: ";
        $stat = 1;
    } else {
        $msg = "OK: ";
        $stat = 1;
    }
    $msg = $msg ."Swap Used Percent - $swap_perc";
    $perf = "swap=$swap_perc:$warn:$crit";
}
### Config Partition Check ###
elsif($check_type eq "config_part" and $warn and $crit) {
    my $config_part_used = ($snmp_session->get_request(-varbindlist => [$s_storageTable_config_part_used]))->{$s_storageTable_config_part_used};
    my $config_part_size = ($snmp_session->get_request(-varbindlist => [$s_storageTable_config_part_size]))->{$s_storageTable_config_part_size};
    my $config_part_perc = sprintf "%.2f", ($config_part_used/$config_part_size)*100;

    if($config_part_perc > $crit) {
        $msg = "CRIT: ";
        $stat = 2;
    } elsif ($config_part_perc > $warn) {
        $msg = "WARN: ";
        $stat = 1;
    } else {
        $msg = "OK: ";
        $stat = 1;
    }
    $msg = $msg ."Config Partition Used Percent - $config_part_perc";
    $perf = "config_part=$config_part_perc:$warn:$crit";
}
### Log Partition Check ###
elsif($check_type eq "log_part" and $warn and $crit) {
    my $log_part_used = ($snmp_session->get_request(-varbindlist => [$s_storageTable_log_part_used]))->{$s_storageTable_log_part_used};
    my $log_part_size = ($snmp_session->get_request(-varbindlist => [$s_storageTable_log_part_size]))->{$s_storageTable_log_part_size};
    my $log_part_perc = sprintf "%.2f", ($log_part_used/$log_part_size)*100;

    if($log_part_perc > $crit) {
        $msg = "CRIT: ";
        $stat = 2;
    } elsif ($log_part_perc > $warn) {
        $msg = "WARN: ";
        $stat = 1;
    } else {
        $msg = "OK: ";
        $stat = 1;
    }
    $msg = $msg ."Log Partition Used Percent - $log_part_perc";
    $perf = "log_part=$log_part_perc:$warn:$crit";
}
### Root Partition Check ###
elsif($check_type eq "root_part" and $warn and $crit) {
    my $root_part_used = ($snmp_session->get_request(-varbindlist => [$s_storageTable_root_part_used]))->{$s_storageTable_root_part_used};
    my $root_part_size = ($snmp_session->get_request(-varbindlist => [$s_storageTable_root_part_size]))->{$s_storageTable_root_part_size};
    my $root_part_perc = sprintf "%.2f", ($root_part_used/$root_part_size)*100;

    if($root_part_perc > $crit) {
        $msg = "CRIT: ";
        $stat = 2;
    } elsif ($root_part_perc > $warn) {
        $msg = "WARN: ";
        $stat = 1;
    } else {
        $msg = "OK: ";
        $stat = 1;
    }
    $msg = $msg ."Root Partition Used Percent - $root_part_perc";
    $perf = "root_part=$root_part_perc:$warn:$crit";
}
elsif($check_type eq "interface") {
    my $s_ifTable_map = {
	'ifDescr' => '1.3.6.1.2.1.2.2.1.2',
	'ifAdminStatus' => '1.3.6.1.2.1.2.2.1.7',
	'ifOperStatus' => '1.3.6.1.2.1.2.2.1.8',
    };

    # Table to store the results of all the queries
    my $ifTable = ();
    my $result = $snmp_session->get_entries(
	-columns => [ values %{$s_ifTable_map}  ],
    );

    my @columnNames = keys %{$s_ifTable_map};
    for my $oid (oid_lex_sort(keys %{$result})) {
        my ($index) = $oid =~ /\.(\d+)$/;
        for my $column (@columnNames) {
	    if (oid_base_match($s_ifTable_map->{$column}, $oid)) {
		$ifTable->{$index}->{$column} = $result->{$oid};
	    }
	}
    }
    my $allnormal = 1;
    my @errorInt;
    for my $index (keys %{$ifTable}) {
        if ($ifTable->{$index}->{'ifOperStatus'} != $ifTable->{$index}->{'ifAdminStatus'}) {
	    $allnormal = 0;
	    push @errorInt, $ifTable->{$index}->{'ifDescr'};
	}
    }

    if ($allnormal != 1) {
	$msg = "CRIT: ".join(" and ",@errorInt)." interface down but administratively up.";
    }
    else {
        $msg = "OK: All Administrativly up interfaces are up.";
    }
}
### Bad Syntax ###
else {
    FSyntaxError();
}

if ($perf eq "") { 
 print "$msg\n";
} else {
 print "$msg | $perf\n";
}

exit($stat);
