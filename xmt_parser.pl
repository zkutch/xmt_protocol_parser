#!/usr/bin/perl
#
#to do:     1)separate structures and functions for each field
#		 2)structures and functions for verbose output

use warnings;
use strict;

use Time::HiRes qw(time gettimeofday);
use POSIX q/strftime/;

use Net::Frame::Dump::Offline;
use Net::Frame::Simple;
use Net::Frame::Layer::UDP qw(:consts);

use NetPacket::UDP;

my %AdmHdr;
my %BusHdr;
my %xmt;
my %Bus_mes_type = (
0x4A => ['Symbol Status', 'J', 'Symbol Status messages contain information regarding 
equity, debenture, or trading Instruments for the current 
trading day for both TSX and TSXV markets. One message 
is disseminated for each valid symbol at the beginning of 
each trading day.'] ,
0x47 => ['Order Book', 'G', 'An Order Book message provides public information for all
open non-terms orders in the market at the start of day. One
message is disseminated for each valid non-terms order at
the beginning of each trading day. Feed clients can use the
Order Book message to initialize their order book for the
current trading day.'],
0x6A => ['Order Book – Terms', 'j', 'An Order Book – Terms message provides public
information for all open terms orders in the market at the
start of day. One message is disseminated for each valid
non-terms order at the beginning of each trading day. Feed
clients can use the Order Book – Terms message to
initialize their order book for the current trading day.'],
0x41 => ['Assign COP – Orders', 'A', 'An Assign COP – Orders message specifies the calculated
opening price (COP) for a security and the participating
orders that are priced at the COP. Each Assign COP –
Orders message can contain up to 15 orders priced at COP,
and the orders are positional. All the orders reported on a
single Assign COP – Orders message always belong to the
same market side.
Note: This message is generated only if one or more
orders are repriced to the COP.'],
0x42 => ['Assign COP – No Orders', 'B', 'An Assign COP – No Order message specifies the
calculated opening price for a security when there are no
orders that are to be repriced to the COP.
Note: This message is generated only if the COP is
changing, but no orders are being repriced to the COP.'],
0x43 => ['Assign Limit', 'C', 'An Assign Limit message is disseminated when former
better-priced-limit orders are reset to their true limits. Each
Assign Limit message can contain up to 15 orders along
with their prices, and the orders are positional. All the orders
reported on a single Assign Limit message always belong to
the same market side.'],
0x45 => ['Market State Update', 'E', 'A Market State Update message is disseminated each time
a notice of a market state change or a trading session
change is sent from the Trading Engine.'],
0x46 => ['MOC Imbalance', 'F', 'A MOC Imbalance message is disseminated for every
MOC-eligible stock. The MOC Imbalance message is
disseminated once per MOC-eligible stock at the beginning
of the MOC Imbalance trading session.'],
0x50 => ['Order Booked', 'P', 'An Order Booked message is disseminated in response to a
new non-terms order being entered into the trading system.'],
0x51 => ['Order Cancelled', 'Q', 'An Order Cancelled message is disseminated if a non-terms
order is cancelled.'],
0x6D => ['Order Booked – Terms', 'm', 'An Order Booked - Terms message is disseminated in
response to a new terms order being entered into the
trading system.'],
0x6E => ['Order Cancelled – Terms', 'n', 'An Order Cancelled – Terms message is disseminated if a
terms order is cancelled.'],
0x52 => ['Order Price-Time Assigned', 'R', 'An Order Price-Time Assigned message is disseminated
when a new Price or Time is assigned to a non-terms order.'],
0x6F => ['Order Price-Time Assigned – Terms', 'o', 'An Order Price-Time Assigned – Terms message is
disseminated if a new Price or Time is assigned to a terms
order.'],
0x49 => ['Stock Status', 'I', 'A Stock Status notification is disseminated in response to a
change in stock status from the Trading Engine.'],
0x53 => ['Trade Report', 'S', 'A Trade Report is generated when a trade occurs that has
no settlement terms.'],
0x70 => ['Trade Report – Terms', 'p', 'A Trade Report – Terms is generated when a trade occurs
that has settlement terms.'],
0x54 => ['Trade Cancelled', 'T', 'A Trade Cancelled message is generated when a trade with
no settlement terms is cancelled.'],
0x71 => ['Trade Cancelled – Terms', 'q', 'A Trade Cancelled – Terms message is generated when a
trade with settlement terms is cancelled.'],
0x55 => ['Trade Correction', 'U', 'A Trade Correction message is generated when a trade with
no settlement terms is corrected'],
0x72 => ['Trade Correction – Terms', 'r', 'A Trade Correction – Terms message is generated when a
trade with settlement terms is corrected.'],
				  );
my $payload;
if ($#ARGV == -1)
	{
		print strftime( q/%H:%M:%S./, localtime ) . ( gettimeofday )[1]."\tYou need to specify file for work in command line. Exiting.\n";
		exit;
	}
if ($#ARGV >= 1)
	{
		print strftime( q/%H:%M:%S./, localtime ) . ( gettimeofday )[1]."\tYou need to specify only one option in command line. Exiting.\n";
		exit;
	}
my $file = $ARGV[0];
print "\n";
if( -f $file)
	{
		print strftime( q/%H:%M:%S./, localtime ) . ( gettimeofday )[1]."\tHad choosed file $file.\n";
	}
else
	{
		print strftime( q/%H:%M:%S./, localtime ) . ( gettimeofday )[1]."\t$file is not file. Exiting.\n";
		exit;
	}
print "\n";
print strftime( q/%H:%M:%S./, localtime ) . ( gettimeofday )[1]."\tStart working..\n";
print strftime( q/%H:%M:%S./, localtime ) . ( gettimeofday )[1]."\tWe are on ", unpack("h*", pack("s*", 1)) =~ /^1/? "little endian": "big endian" ," byteorder comp.\n";

my $counter = 0;
my $Offline_Dump = Net::Frame::Dump::Offline->new(file => $file);
$Offline_Dump->start;
for(;;)
{	
	++$counter;
        my $h = $Offline_Dump->next ;
        last unless $h ;
	my $h_raw =$h->{'raw'};  
	unless (defined $h_raw)
		{
			print strftime( q/%H:%M:%S./, localtime ) . ( gettimeofday )[1]."\tCannot get raw data from $counter udp packet. Skiping this packet.\n";
			next;
		}	
	my $f = Net::Frame::Simple->new(
							      raw        => $h->{raw},
							      firstLayer => $h->{firstLayer},
							      timestamp  => $h->{timestamp},
							 );  
	 
	
	my @net_frame_simple_array = @{$f};
	my %layers_hash = %{$net_frame_simple_array[5]};
	my @udp_layer = $layers_hash{'UDP'};  
	 
	my $raw = @{$udp_layer[0]}[4];
	my $udp_obj = NetPacket::UDP->decode($raw);
	my %udp_hash = %{$udp_obj};
	
	print "\n";
	print strftime( q/%H:%M:%S./, localtime ) . ( gettimeofday )[1]."\tDecoding $counter UDP packet:\n";
	print "\t\t\t\tParent is : ",(defined $udp_hash{_parent} ? $udp_hash{_parent} : "undef"),".\n";
	print "\t\t\t\tChecksum is : ",(defined $udp_hash{cksum} ? $udp_hash{cksum} : "undef"),".\n";
	print "\t\t\t\tSource port is : ",(defined $udp_hash{src_port} ? $udp_hash{src_port} : "undef"),".\n";
	print "\t\t\t\tDestination port is : ",(defined $udp_hash{dest_port} ? $udp_hash{dest_port} : "undef"),".\n";
	print "\t\t\t\tLength is : ",(defined $udp_hash{len} ? $udp_hash{len} : "undef"),"\n";
	print "\n";
	unless( defined $udp_hash{data})
		{
			print strftime( q/%H:%M:%S./, localtime ) . ( gettimeofday )[1]."\tCannot get payload from udp packet. Skiping this packet.\n";
			next;
		}
	$payload = unpack('H*', $udp_obj ->{data}) ;
	print "\t\t\t\tPayload Hex high nybble first is :\n",(defined $udp_hash{data} ? $payload : "undef"),"\n";
	
	print "\n";
	print strftime( q/%H:%M:%S./, localtime ) . ( gettimeofday )[1]."\tAnalyzing UDP payload:\n";
	print "\t\t\t\tWe have raw data:\n",$udp_hash{data},"\n"; 
	%xmt = (
				start_of_frame => substr($payload, 0, 2),
				protocol_name => substr($payload, 2, 2),
				protocol_version => substr($payload, 4, 2),
				message_length => substr($payload, 6, 4),
				Session_ID => substr($payload, 10, 8),
				Ack_Req_Poss_Dup => substr($payload, 18, 2),
				Num_Body => substr($payload, 20, 2),				
			  ) ;
	%AdmHdr = (
					Msg_Length => substr($payload, 22, 4),
					Msg_Type => substr($payload, 26, 2),
					Admin_ID =>  substr($payload, 28, 2),
					Hb_Interval => substr($payload, 30, 4),
					
					Source_ID => substr($payload, 34, 2),
					Stream_ID => substr($payload, 36, 4),
					Sequence_0 => substr($payload, 40, 2),
					Sequence_1 => substr($payload, 42, 8),
					
					Replay_Win_Size => substr($payload, 34, 4),
					Replay_Win_Num => substr($payload, 38, 4),
					Login_Request_Credits => substr($payload, 42, 4),
					
					Replay_Win => substr($payload, 42, 2),
					Login_Response_Credits => substr($payload, 44, 4),
					
					Session_ID => substr($payload, 30, 8),
					
					Sequence_Jump_Reason_Code => substr($payload, 30, 2), #same for Operation Code
					
					Operation_message => substr($payload, 32, 200),
					
					Reject_Code => substr($payload, 30, 2),
					Reject_Subcode => substr($payload, 32, 2),
					Reject_message => substr($payload, 34, 60),
				 );
	%BusHdr = (
					Msg_Length => substr($payload, 22, 4),
					Msg_Type => substr($payload, 26, 2),
					Msg_Version =>  substr($payload, 28, 2),
					Source_ID => substr($payload, 30, 2),					
					Stream_ID => substr($payload, 32, 4),					
					Sequence_0 => substr($payload, 36, 2),
					Sequence_1 => substr($payload, 38, 8),				
					
				 );
	
		{
			print "\t\t\t\tStart of frame is : ", $xmt{start_of_frame},".\n";			
		}	
	if( check_Alphanumeric( $xmt{protocol_name})  )
		{
			print "\t\t\t\tProtocol name is : ",pack('H2', $xmt{protocol_name}),".\n";			
		}
	else
		{
			print "\t\t\t\tWrong protocol name is : ",pack('H2', $xmt{protocol_name}),".\n";
		}
	if( check_Numeric( $xmt{protocol_version})  )
		{
			print "\t\t\t\tProtocol version is : ",pack('H2', $xmt{protocol_version}),".\n";			
		}
	else
		{
			print "\t\t\t\tWrong protocol version is : ",pack('H2', $xmt{protocol_version}),".\n";
		}		
		{								
			print "\t\t\t\tMessage length is : ",hex(unpack("h2", pack("h2", $xmt{message_length}))),".\n";
		}	
		{								
			print "\t\t\t\tSession_ID is : ", hex(reverse(unpack("h8", pack("H8", $xmt{Session_ID})))),".\n";
		}	
	if( check_Alphanumeric( $xmt{Ack_Req_Poss_Dup} ) )
		{								
			print "\t\t\t\tAck_Req_Poss_Dup is : ", pack("H2", $xmt{Ack_Req_Poss_Dup}),".\n";
		}
	else
		{
			print "\t\t\t\tWrong Ack_Req_Poss_Dup : ",pack("H2", $xmt{Ack_Req_Poss_Dup}),".\n";
		}	
		{
			print "\t\t\t\tNum_Body is : ",$xmt{Num_Body},".\n";			
		}	
	#Admin Or Business
	if ($AdmHdr{Msg_Type} =~ /\d{2}/ ) 
		{
			if ( 30 <= $AdmHdr{Msg_Type} and $AdmHdr{Msg_Type} <= 39)
				{
					print "\n\t\t\t\tFound Admin Header.\n";
					Admin_header();
				}
			elsif( hex(41) <= hex($AdmHdr{Msg_Type}) and hex($AdmHdr{Msg_Type}) <= hex('7e'))
				{
					print "\t\t\t\tFound Business Header.\n";
					Business_header();
				}
			else
				{
					print "\t\t\t\tFound wrong Header ",$AdmHdr{Msg_Type}," . Skipping.\n";
					next;
				}
		}
	else
		{
			if ( hex(41) <= hex($AdmHdr{Msg_Type}) and hex($AdmHdr{Msg_Type}) <= hex('7e'))
				{
					print "\t\t\t\tFound Business Header.\n";
					Business_header();
				}
			else
				{
					print "\t\t\t\tFound wrong Header ",$AdmHdr{Msg_Type}," . Skipping.\n";
					next;
				}
		}
	
	print "\n";
	

 }
$Offline_Dump->stop;	



print strftime( q/%H:%M:%S./, localtime ) . ( gettimeofday )[1]."\tFinish working..\n";
print "\n";

sub Business_header
{
	print "\n";	
	print "\t\t\t\tBusiness Header Message length ",hex(scalar reverse(unpack("h4", pack("H4", $BusHdr{Msg_Length})))),".\n";		
	print "\t\t\t\tBusiness Header Message Type 0x", $BusHdr{Msg_Type},' Message Name '."'".Business_message_type(hex $BusHdr{Msg_Type})."'".".\n";
	print "\t\t\t\tBusiness Header Message Version ",hex(unpack("h2", pack("h2", $BusHdr{Msg_Version}))),".\n";
	print "\t\t\t\tBusiness Header Source ID ", chr(hex $BusHdr{Source_ID}),".\n";
	my $correct = scalar reverse(unpack("h4", pack("H4", $BusHdr{Stream_ID}))) ;
	$correct =~ s/^0*//;	
	print "\t\t\t\tBusiness Header Stream ID ",hex($correct),".\n";
	print "\t\t\t\tBusiness Header Sequence-0 ",hex(unpack("h2", pack("H2", $BusHdr{Sequence_0}))),".\n";	
	print "\t\t\t\tBusiness Header Sequence-1 ",hex(scalar reverse(unpack("h8", pack("H8", $BusHdr{Sequence_1})))),".\n";	
	print "\n";	
	
	Symbol_Status() if(hex $BusHdr{Msg_Type} == 0x4A);
	Order_Book() if(hex $BusHdr{Msg_Type} == 0x47);
	Order_Book_Terms() if(hex $BusHdr{Msg_Type} == 0x6A);
	Assign_COP_Orders() if(hex $BusHdr{Msg_Type} == 0x41);
	Assign_COP_No_Orders() if(hex $BusHdr{Msg_Type} == 0x42);
	Assign_Limit() if(hex $BusHdr{Msg_Type} == 0x43);
	Market_State_Update() if(hex $BusHdr{Msg_Type} == 0x45);
	MOC_Imbalance() if(hex $BusHdr{Msg_Type} == 0x46);
	Order_Booked() if(hex $BusHdr{Msg_Type} == 0x50);
	Order_Booked_Terms() if(hex $BusHdr{Msg_Type} == 0x6D);
	Order_Cancelled() if(hex $BusHdr{Msg_Type} == 0x51);	
	Order_Cancelled_Terms() if(hex $BusHdr{Msg_Type} == 0x6E);
	Order_Price_Time_Assigned() if(hex $BusHdr{Msg_Type} == 0x52);
	Order_Price_Time_Assigned_Terms() if(hex $BusHdr{Msg_Type} == 0x6F);
	Stock_Status() if(hex $BusHdr{Msg_Type} == 0x49);
	Trade_Report() if(hex $BusHdr{Msg_Type} == 0x53);
	Trade_Report_Terms() if(hex $BusHdr{Msg_Type} == 0x70);
	Trade_Cancelled() if(hex $BusHdr{Msg_Type} == 0x54);
	Trade_Cancelled_Terms() if(hex $BusHdr{Msg_Type} == 0x71);
	Trade_Correction() if(hex $BusHdr{Msg_Type} == 0x55);
	Trade_Correction_Terms() if(hex $BusHdr{Msg_Type} == 0x72);	
}

sub Business_message_type
{
	my $key = shift;
	foreach my $i (keys %Bus_mes_type)
		{
			return $Bus_mes_type{$key}->[0] if($i == $key); # ."'".' ASCII type '.$Bus_mes_type{$key}->[1]  Intraday messages
		}
	return "undef";	
}

sub Symbol_Status
{
	print "\t\t\t\tThis is  Start-of-Day message.\n";
	print "\t\t\t\tBusiness Message type is '",Business_message_type(hex $BusHdr{Msg_Type}),"'.\n";
	print "\t\t\t\tBusiness Body Symbol is ",hex(unpack("h18", pack("h18", substr($payload, 46, 18)))),".\n";
	print "\t\t\t\tBusiness Body Stock Group is ",substr($payload, 64, 2),".\n";
	print "\t\t\t\tBusiness Body CUSIP is ",substr($payload, 66, 24),".\n";
	print "\t\t\t\tBusiness Body Board Lot is ",substr($payload, 90, 4),".\n";
	print "\t\t\t\tBusiness Body Currency is ",substr($payload, 94, 2),".\n";
	print "\t\t\t\tBusiness Body Face Value is ",substr($payload, 96, 16),".\n";
	print "\t\t\t\tBusiness Body Last Sale is ",substr($payload, 112, 16),".\n";
}

sub Order_Book
{
	print "\t\t\t\tThis is  Start-of-Day message.\n";
	print "\t\t\t\tBusiness Message type is '",Business_message_type(hex $BusHdr{Msg_Type}),"'.\n";
	print "\t\t\t\tBusiness Body Symbol is ",hex(unpack("h18", pack("h18", substr($payload, 46, 18)))),".\n";
	print "\t\t\t\tBusiness Body Broker Number is ",substr($payload, 64, 4),".\n";
	print "\t\t\t\tBusiness Body Order Side is ",Order_Side_Value(substr($payload, 68, 2)),".\n";	
	print "\t\t\t\tBusiness Body Order ID is ",unpack("j16", pack "H16", substr($payload, 70, 16)),".\n";
	print "\t\t\t\tBusiness Body Price is ",unpack("j16", pack("H16", substr($payload, 86, 16)))/1000000,".\n";
	print "\t\t\t\tBusiness Body Volume is ",unpack("j16", pack("H16",substr($payload, 102, 8))),".\n"; 	
	print "\t\t\t\tBusiness Body Priority Time Stamp is ",Priority_Time_Stamp_Value(substr($payload, 110, 16)).".\n";
}

sub Priority_Time_Stamp_Value
{
	my $value = shift;
	my $epoch = substr(unpack("j16", pack("H16", $value)), 0, 10);
	my $microseconds = substr(unpack("j16", pack("H16",$value)), 10, 6);
	return strftime("%d/%m/%Y %H:%M:%S.",localtime($epoch)).$microseconds;
}

sub Order_Book_Terms
{
	print "\t\t\t\tThis is  Start-of-Day message.\n";
	print "\t\t\t\tBusiness Message type is '",Business_message_type(hex $BusHdr{Msg_Type}),"'.\n";
	print "\t\t\t\tBusiness Body Symbol is ",hex(unpack("h18", pack("h18", substr($payload, 46, 18)))),".\n";
	print "\t\t\t\tBusiness Body Broker Number is ",substr($payload, 64, 4),".\n";
	print "\t\t\t\tBusiness Body Order Side is ",Order_Side_Value(substr($payload, 68, 2)),".\n";	
	print "\t\t\t\tBusiness Body Order ID is ",unpack("j16", pack "H16", substr($payload, 70, 16)),".\n";
	print "\t\t\t\tBusiness Body Price is ",unpack("j16", pack("H16", substr($payload, 86, 16)))/1000000,".\n";
	print "\t\t\t\tBusiness Body Volume is ",unpack("j16", pack("H16",substr($payload, 102, 8))),".\n";
	print "\t\t\t\tBusiness Body Non Resident is ",substr($payload, 110, 2),".\n";
	print "\t\t\t\tBusiness Body Settlement Terms is ",Settlement_Terms_Value (substr($payload, 112, 2)),"\n";
	print "\t\t\t\tBusiness Body Settlement Date is ",substr($payload, 114, 8),".\n";	
	print "\t\t\t\tBusiness Body Priority Time Stamp is ",Priority_Time_Stamp_Value(substr($payload, 122, 16)).".\n";
}

sub Assign_COP_Orders
{	
	print "\t\t\t\tThis is Special Market/Stock State Message.\n";
	print "\t\t\t\tBusiness Message type is '",Business_message_type(hex $BusHdr{Msg_Type}),"'.\n";
	print "\t\t\t\tBusiness Body Symbol is ",pack("H18", substr($payload, 46, 18)),"\n"; 
	print "\t\t\t\tBusiness Body Calculated Opening Price is ",unpack("j16", pack("H16", substr($payload, 64, 16)))/1000000,".\n";
	print "\t\t\t\tBusiness Body Order Side is ",Order_Side_Value(substr($payload, 80, 2)),".\n";
	print "\t\t\t\tBusiness Body Broker Number-1 is ",Number_N_Value( substr($payload, 82, 4)),".\n";
	print "\t\t\t\tBusiness Body Order ID-1 is ",unpack("j16", pack "H16", substr($payload, 86, 16)),".\n";
	print "\t\t\t\tBusiness Body Broker Number-2 is ",Number_N_Value(substr($payload, 102, 4)),".\n";       
	print "\t\t\t\tBusiness Body Order ID-2 is ",unpack("j16", pack "H16", substr($payload, 106, 16)),".\n";
	print "\t\t\t\tBusiness Body Broker Number-3 is ",Number_N_Value(substr($payload, 122, 4)),".\n";
	print "\t\t\t\tBusiness Body Order ID-3 is ",unpack("j16", pack "H16", substr($payload, 126, 16)),".\n";
	print "\t\t\t\tBusiness Body Broker Number-4 is ",Number_N_Value(substr($payload, 142, 4)),".\n";
	print "\t\t\t\tBusiness Body Order ID-4 is ",unpack("j16", pack "H16", substr($payload, 146, 16)),".\n";
	print "\t\t\t\tBusiness Body Broker Number-5 is ",Number_N_Value(substr($payload, 162, 4)),".\n";
	print "\t\t\t\tBusiness Body Order ID-5 is ",unpack("j16", pack "H16", substr($payload, 166, 16)),".\n";
	print "\t\t\t\tBusiness Body Broker Number-6 is ",Number_N_Value(substr($payload, 182, 4)),".\n";
	print "\t\t\t\tBusiness Body Order ID-6 is ",unpack("j16", pack "H16", substr($payload, 186, 16)),".\n";
	print "\t\t\t\tBusiness Body Broker Number-7 is ",Number_N_Value(substr($payload, 202, 4)),".\n";
	print "\t\t\t\tBusiness Body Order ID-7 is ",unpack("j16", pack "H16", substr($payload, 206, 16)),".\n";
	print "\t\t\t\tBusiness Body Broker Number-8 is ",Number_N_Value(substr($payload, 222, 4)),".\n";
	print "\t\t\t\tBusiness Body Order ID-8 is ",unpack("j16", pack "H16", substr($payload, 226, 16)),".\n";
	print "\t\t\t\tBusiness Body Broker Number-9 is ",Number_N_Value(substr($payload, 242, 4)),".\n";
	print "\t\t\t\tBusiness Body Order ID-9 is ",unpack("j16", pack "H16", substr($payload, 246, 16)),".\n";
	print "\t\t\t\tBusiness Body Broker Number-10 is ",Number_N_Value(substr($payload, 262, 4)),".\n";
	print "\t\t\t\tBusiness Body Order ID-10 is ",unpack("j16", pack "H16", substr($payload, 266, 16)),".\n";
	print "\t\t\t\tBusiness Body Broker Number-11 is ",Number_N_Value(substr($payload, 282, 4)),".\n";
	print "\t\t\t\tBusiness Body Order ID-11 is ",unpack("j16", pack "H16", substr($payload, 286, 16)),".\n";
	print "\t\t\t\tBusiness Body Broker Number-12 is ",Number_N_Value(substr($payload, 302, 4)),".\n";
	print "\t\t\t\tBusiness Body Order ID-12 is ",unpack("j16", pack "H16", substr($payload, 306, 16)),".\n";
	print "\t\t\t\tBusiness Body Broker Number-13 is ",Number_N_Value(substr($payload, 322, 4)),".\n";
	print "\t\t\t\tBusiness Body Order ID-13 is ",unpack("j16", pack "H16", substr($payload, 326, 16)),".\n";
	print "\t\t\t\tBusiness Body Broker Number-14 is ",Number_N_Value(substr($payload, 342, 4)),".\n";
	print "\t\t\t\tBusiness Body Order ID-14 is ",unpack("j16", pack "H16", substr($payload, 346, 16)),".\n";
	print "\t\t\t\tBusiness Body Broker Number-15 is ",Number_N_Value(substr($payload, 362, 4)),".\n";
	print "\t\t\t\tBusiness Body Order ID-15 is ",unpack("j16", pack "H16", substr($payload, 366, 16)),".\n";	
	print "\t\t\t\tBusiness Body Trading System Time Stamp is ",Priority_Time_Stamp_Value(substr($payload, 382, 16)).".\n";	
}

sub Number_N_Value
{
	return unpack("W4", pack("H4", shift));
}

sub Order_Side_Value
{
	my $value =  chr(hex(unpack("h2", pack("h2", shift))));
	return $value.' Buy' if($value eq 'B');
	return $value.' Sell' if($value eq 'S');	
	return $value.' Wrong Value for Order Side.';	
}

sub Assign_COP_No_Orders
{
	print "\t\t\t\tThis is Special Market/Stock State Message.\n";
	print "\t\t\t\tBusiness Message type is '",Business_message_type(hex $BusHdr{Msg_Type}),"'.\n";
	print "\t\t\t\tBusiness Body Symbol is ",pack("H18", substr($payload, 46, 18)),"\n"; 
	print "\t\t\t\tBusiness Body Calculated Opening Price is ",unpack("j16", pack("H16", substr($payload, 64, 16)))/1000000,".\n";	
	print "\t\t\t\tBusiness Body Trading System Time Stamp is ",Priority_Time_Stamp_Value(substr($payload, 80, 16)).".\n";
}

sub Assign_Limit
{
	print "\t\t\t\tThis is Special Market/Stock State Message.\n";
	print "\t\t\t\tBusiness Message type is '",Business_message_type(hex $BusHdr{Msg_Type}),"'.\n";
	print "\t\t\t\tBusiness Body Symbol is ",pack("H18", substr($payload, 46, 18)),"\n"; 
	print "\t\t\t\tBusiness Body Calculated Opening Price is ",unpack("j16", pack("H16", substr($payload, 64, 16)))/1000000,".\n";
	print "\t\t\t\tBusiness Body Order Side is ",Order_Side_Value(substr($payload, 80, 2)),".\n"; 
	print "\t\t\t\tBusiness Body Broker Number-1 is ",Number_N_Value(substr($payload, 82, 4)),".\n";
	print "\t\t\t\tBusiness Body Order ID-1 is ",unpack("j16", pack "H16", substr($payload, 86, 16)),".\n";
	print "\t\t\t\tBusiness Body Price-1 is ",unpack("j16", pack("H16", substr($payload, 102, 16)))/1000000,".\n";
	print "\t\t\t\tBusiness Body Broker Number-2 is ",Number_N_Value(substr($payload, 118, 4)),".\n";
	print "\t\t\t\tBusiness Body Order ID-2 is ",unpack("j16", pack "H16", substr($payload, 122, 16)),".\n";
	print "\t\t\t\tBusiness Body Price-2 is ",unpack("j16", pack("H16", substr($payload, 138, 16)))/1000000,".\n";
	print "\t\t\t\tBusiness Body Broker Number-3 is ",Number_N_Value(substr($payload, 154, 4)),".\n";
	print "\t\t\t\tBusiness Body Order ID-3 is ",unpack("j16", pack "H16", substr($payload, 158, 16)),".\n";
	print "\t\t\t\tBusiness Body Price-3 is ",unpack("j16", pack("H16", substr($payload, 164, 16)))/1000000,".\n";
	print "\t\t\t\tBusiness Body Broker Number-4 is ",Number_N_Value(substr($payload, 180, 4)),".\n";
	print "\t\t\t\tBusiness Body Order ID-4 is ",unpack("j16", pack "H16", substr($payload, 184, 16)),".\n";
	print "\t\t\t\tBusiness Body Price-4 is ",unpack("j16", pack("H16", substr($payload, 200, 16)))/1000000,".\n";
	print "\t\t\t\tBusiness Body Broker Number-5 is ",Number_N_Value(substr($payload, 216, 4)),".\n";
	print "\t\t\t\tBusiness Body Order ID-5 is ",unpack("j16", pack "H16", substr($payload, 220, 16)),".\n";
	print "\t\t\t\tBusiness Body Price-5 is ",unpack("j16", pack("H16", substr($payload, 236, 16)))/1000000,".\n";
	print "\t\t\t\tBusiness Body Broker Number-6 is ",Number_N_Value(substr($payload, 252, 4)),".\n";
	print "\t\t\t\tBusiness Body Order ID-6 is ",unpack("j16", pack "H16", substr($payload, 256, 16)),".\n";
	print "\t\t\t\tBusiness Body Price-6 is ",unpack("j16", pack("H16", substr($payload, 272, 16)))/1000000,".\n";
	print "\t\t\t\tBusiness Body Broker Number-7 is ",Number_N_Value(substr($payload, 288, 4)),".\n";
	print "\t\t\t\tBusiness Body Order ID-7 is ",unpack("j16", pack "H16", substr($payload, 292, 16)),".\n";
	print "\t\t\t\tBusiness Body Price-7 is ",unpack("j16", pack("H16", substr($payload, 308, 16)))/1000000,".\n";
	print "\t\t\t\tBusiness Body Broker Number-8 is ",Number_N_Value(substr($payload, 324, 4)),".\n";
	print "\t\t\t\tBusiness Body Order ID-8 is ",unpack("j16", pack "H16", substr($payload, 328, 16)),".\n";
	print "\t\t\t\tBusiness Body Price-8 is ",unpack("j16", pack("H16", substr($payload, 344, 16)))/1000000,".\n";
	print "\t\t\t\tBusiness Body Broker Number-9 is ",Number_N_Value(substr($payload, 360, 4)),".\n";
	print "\t\t\t\tBusiness Body Order ID-9 is ",unpack("j16", pack "H16", substr($payload, 364, 16)),".\n";
	print "\t\t\t\tBusiness Body Price-9 is ",unpack("j16", pack("H16", substr($payload, 380, 16)))/1000000,".\n";
	print "\t\t\t\tBusiness Body Broker Number-10 is ",Number_N_Value(substr($payload, 396, 4)),".\n";
	print "\t\t\t\tBusiness Body Order ID-10 is ",unpack("j16", pack "H16", substr($payload, 400, 16)),".\n";
	print "\t\t\t\tBusiness Body Price-10 is ",unpack("j16", pack("H16", substr($payload, 416, 16)))/1000000,".\n";
	print "\t\t\t\tBusiness Body Broker Number-11 is ",Number_N_Value(substr($payload, 432, 4)),".\n";
	print "\t\t\t\tBusiness Body Order ID-11 is ",unpack("j16", pack "H16", substr($payload, 436, 16)),".\n";
	print "\t\t\t\tBusiness Body Price-11 is ",unpack("j16", pack("H16", substr($payload, 452, 16)))/1000000,".\n";
	print "\t\t\t\tBusiness Body Broker Number-12 is ",Number_N_Value(substr($payload, 468, 4)),".\n";
	print "\t\t\t\tBusiness Body Order ID-12 is ",unpack("j16", pack "H16", substr($payload, 472, 16)),".\n";
	print "\t\t\t\tBusiness Body Price-12 is ",unpack("j16", pack("H16", substr($payload, 488, 16)))/1000000,".\n";
	print "\t\t\t\tBusiness Body Broker Number-13 is ",Number_N_Value(substr($payload, 504, 4)),".\n";
	print "\t\t\t\tBusiness Body Order ID-13 is ",unpack("j16", pack "H16", substr($payload, 508, 16)),".\n";
	print "\t\t\t\tBusiness Body Price-13 is ",unpack("j16", pack("H16", substr($payload, 524, 16)))/1000000,".\n";
	print "\t\t\t\tBusiness Body Broker Number-14 is ",Number_N_Value(substr($payload, 540, 4)),".\n";
	print "\t\t\t\tBusiness Body Order ID-14 is ",unpack("j16", pack "H16", substr($payload, 544, 16)),".\n";
	print "\t\t\t\tBusiness Body Price-14 is ",unpack("j16", pack("H16", substr($payload, 560, 16)))/1000000,".\n";
	print "\t\t\t\tBusiness Body Broker Number-15 is ",Number_N_Value(substr($payload, 576, 4)),".\n";
	print "\t\t\t\tBusiness Body Order ID-15 is ",unpack("j16", pack "H16", substr($payload, 580, 16)),".\n";
	print "\t\t\t\tBusiness Body Price-15 is ",unpack("j16", pack("H16", substr($payload, 596, 16)))/1000000,".\n";
	my $epoch = substr(unpack("j16", pack "H16", substr($payload, 612, 16)), 0, 10);
	my $microseconds = substr(unpack("j16", pack("H16", substr($payload, 612, 16))), 10, 6);
	print "\t\t\t\tBusiness Body Trading System Time Stamp is ",Priority_Time_Stamp_Value(substr($payload, 612, 16)).".\n";
}

sub Market_State_Update
{
	print "\t\t\t\tThis is Intraday message.\n";
	print "\t\t\t\tBusiness Message type is '",Business_message_type(hex $BusHdr{Msg_Type}),"'.\n";	 
	print "\t\t\t\tBusiness Body Market State is ",Market_State_Value(substr($payload, 46, 2)),"\n"; 
	print "\t\t\t\tBusiness Body Broker Number is ",Number_N_Value(substr($payload, 48, 2)),".\n";	
	print "\t\t\t\tBusiness Body Trading System Time Stamp is ",Priority_Time_Stamp_Value(substr($payload, 50, 16)).".\n";
}

sub Market_State_Value
{
	my $value = chr(hex(shift));
	return $value.' Pre-open.' if($value eq 'P');
	return $value.' Opening.' if($value eq 'O');
	return $value.' Open.' if($value eq 'S');
	return $value.' Closed.' if($value eq 'C');
	return $value.' Extended Hours Open.' if($value eq 'R');
	return $value.' Extended Hours Close.' if($value eq 'F');
	return $value.' Extended Hours CXLs.' if($value eq 'N');
	return $value.' MOC Imbalance.' if($value eq 'M');
	return $value.' CCP Determination.' if($value eq 'A');
	return $value.' Price Movement Extension.' if($value eq 'E');
	return $value.' Closing.' if($value eq 'L');
	return $value.' Wrong Value for Market State.';	
}

sub MOC_Imbalance
{
	print "\t\t\t\tThis is Intraday message.\n";
	print "\t\t\t\tBusiness Message type is '",Business_message_type(hex $BusHdr{Msg_Type}),"'.\n";
	print "\t\t\t\tBusiness Body Symbol is ",pack("H18", substr($payload, 46, 18)),"\n";
	print "\t\t\t\tBusiness Body Imbalance Side is ",chr(hex(unpack("h2", pack("h2", substr($payload, 64, 2))))),".\n";
	print "\t\t\t\tBusiness Body Imbalance Volume is ",unpack("j16", pack("H16",substr($payload, 66, 8))),".\n";	
	print "\t\t\t\tBusiness Body Trading System Time Stamp is ",Priority_Time_Stamp_Value(substr($payload, 74, 16)).".\n";
	print "\t\t\t\tBusiness Body Imbalance Reference Price is ",unpack("j16", pack("H16", substr($payload, 90, 16)))/1000000,".\n";
}

sub Order_Booked
{
	print "\t\t\t\tThis is Intraday message.\n";
	print "\t\t\t\tBusiness Message type is '",Business_message_type(hex $BusHdr{Msg_Type}),"'.\n";
	print "\t\t\t\tBusiness Body Symbol is ",pack("H18", substr($payload, 46, 18)),"\n";
	print "\t\t\t\tBusiness Body Broker Number is ",Number_N_Value(substr($payload, 64, 4)),".\n";
	print "\t\t\t\tBusiness Body Order Side is ",Order_Side_Value(substr($payload, 68, 2)),".\n";	
	print "\t\t\t\tBusiness Body Order ID is ",unpack("j16", pack "H16", substr($payload, 70, 16)),".\n";
	print "\t\t\t\tBusiness Body Price is ",unpack("j16", pack("H16", substr($payload, 86, 16)))/1000000,".\n";
	print "\t\t\t\tBusiness Body Volume is ",unpack("j16", pack("H16",substr($payload, 102, 8))),".\n";	
	print "\t\t\t\tBusiness Body Priority Time Stamp is ",Priority_Time_Stamp_Value(substr($payload, 110, 16)).".\n";	
	print "\t\t\t\tBusiness Body Trading System Time Stamp is ",Priority_Time_Stamp_Value(substr($payload, 126, 16)).".\n";
}

sub Order_Booked_Terms
{
	print "\t\t\t\tThis is Intraday message.\n";
	print "\t\t\t\tBusiness Message type is '",Business_message_type(hex $BusHdr{Msg_Type}),"'.\n";
	print "\t\t\t\tBusiness Body Symbol is ",pack("H18", substr($payload, 46, 18)),"\n";
	print "\t\t\t\tBusiness Body Broker Number is ",Number_N_Value(substr($payload, 64, 4)),".\n";
	print "\t\t\t\tBusiness Body Order Side is ",Order_Side_Value(substr($payload, 68, 2)),".\n";	
	print "\t\t\t\tBusiness Body Order ID is ",unpack("j16", pack "H16", substr($payload, 70, 16)),".\n";
	print "\t\t\t\tBusiness Body Price is ",unpack("j16", pack("H16", substr($payload, 86, 16)))/1000000,".\n";
	print "\t\t\t\tBusiness Body Volume is ",unpack("j16", pack("H16",substr($payload, 102, 8))),".\n";
	print "\t\t\t\tBusiness Body Non Resident is ",Non_Resident_Value (substr($payload, 110, 2)),"\n"; 
	print "\t\t\t\tBusiness Body Settlement Terms is ",Settlement_Terms_Value (substr($payload, 112, 2)),"\n";
	my $date = unpack("j16", pack "H16", substr($payload, 114, 8)); 
	print "\t\t\t\tBusiness Body Settlement Date is ",$date,".\n";	
	print "\t\t\t\tBusiness Body Priority Time Stamp is ",Priority_Time_Stamp_Value(substr($payload, 122, 16)).".\n";	
	print "\t\t\t\tBusiness Body Trading System Time Stamp is ",Priority_Time_Stamp_Value(substr($payload, 138, 16)).".\n";
}

sub Non_Resident_Value
{
	my $value = chr(hex(shift));
	return $value.'  Participant is not a Canadian resident.' if($value eq 'Y');
	return $value.' Participant is a Canadian resident.' if($value eq 'N');	
	return $value.' Wrong Value for Non Resident.';
}

sub Settlement_Terms_Value
{
	my $value = chr(hex(shift));
	return $value.'  Cash.' if($value eq 'C');
	return $value.' NN.' if($value eq 'N');	
	return $value.' MS.' if($value eq 'M');	
	return $value.' CT.' if($value eq 'T');	
	return $value.' ' if($value eq 'D');	
	return $value.' Wrong Value for Settlement Terms.';
}

sub Order_Cancelled
{
	print "\t\t\t\tThis is Intraday message.\n";
	print "\t\t\t\tBusiness Message type is '",Business_message_type(hex $BusHdr{Msg_Type}),"'.\n";
	print "\t\t\t\tBusiness Body Symbol is ",pack("H18", substr($payload, 46, 18)),"\n";
	print "\t\t\t\tBusiness Body Broker Number is ",Number_N_Value(substr($payload, 64, 4)),".\n";
	print "\t\t\t\tBusiness Body Order Side is ",Order_Side_Value(substr($payload, 68, 2)),".\n";	
	print "\t\t\t\tBusiness Body Order ID is ",unpack("j16", pack "H16", substr($payload, 70, 16)),".\n";	
	print "\t\t\t\tBusiness Body Trading System Time Stamp is ",Priority_Time_Stamp_Value(substr($payload, 86, 16)).".\n";
}

sub Order_Cancelled_Terms
{
	print "\t\t\t\tThis is Intraday message.\n";
	print "\t\t\t\tBusiness Message type is '",Business_message_type(hex $BusHdr{Msg_Type}),"'.\n";
	print "\t\t\t\tBusiness Body Symbol is ",pack("H18", substr($payload, 46, 18)),"\n";
	print "\t\t\t\tBusiness Body Broker Number is ",Number_N_Value(substr($payload, 64, 4)),".\n";
	print "\t\t\t\tBusiness Body Order Side is ",Order_Side_Value(substr($payload, 68, 2)),".\n"; 
	print "\t\t\t\tBusiness Body Order ID is ",unpack("j16", pack "H16", substr($payload, 70, 16)),".\n";	
	print "\t\t\t\tBusiness Body Trading System Time Stamp is ",Priority_Time_Stamp_Value(substr($payload, 86, 16)).".\n";
}

sub Order_Price_Time_Assigned
{
	print "\t\t\t\tThis is Intraday message.\n";
	print "\t\t\t\tBusiness Message type is '",Business_message_type(hex $BusHdr{Msg_Type}),"'.\n";
	print "\t\t\t\tBusiness Body Symbol is ",pack("H18", substr($payload, 46, 18)),"\n";
	print "\t\t\t\tBusiness Body Broker Number is ",Number_N_Value(substr($payload, 64, 4)),".\n";
	print "\t\t\t\tBusiness Body Order Side is ",Order_Side_Value(substr($payload, 68, 2)),".\n"; 
	print "\t\t\t\tBusiness Body Order ID is ",unpack("j16", pack "H16", substr($payload, 70, 16)),".\n";
	print "\t\t\t\tBusiness Body Price is ",unpack("j16", pack("H16", substr($payload, 86, 16)))/1000000,".\n";
	print "\t\t\t\tBusiness Body Volume is ",unpack("j16", pack("H16",substr($payload, 102, 8))),".\n";	
	print "\t\t\t\tBusiness Body Priority Time Stamp is ",Priority_Time_Stamp_Value(substr($payload, 110, 16)).".\n";	
	print "\t\t\t\tBusiness Body Trading System Time Stamp is ",Priority_Time_Stamp_Value(substr($payload, 126, 16)).".\n";
}

sub Order_Price_Time_Assigned_Terms
{
	print "\t\t\t\tThis is Intraday message.\n";
	print "\t\t\t\tBusiness Message type is '",Business_message_type(hex $BusHdr{Msg_Type}),"'.\n";
	print "\t\t\t\tBusiness Body Symbol is ",pack("H18", substr($payload, 46, 18)),"\n";
	print "\t\t\t\tBusiness Body Broker Number is ",Number_N_Value(substr($payload, 64, 4)),".\n";
	print "\t\t\t\tBusiness Body Order Side is ",Order_Side_Value(substr($payload, 68, 2)),".\n"; 
	print "\t\t\t\tBusiness Body Order ID is ",unpack("j16", pack "H16", substr($payload, 70, 16)),".\n";
	print "\t\t\t\tBusiness Body Price is ",unpack("j16", pack("H16", substr($payload, 86, 16)))/1000000,".\n";
	print "\t\t\t\tBusiness Body Volume is ",unpack("j16", pack("H16",substr($payload, 102, 8))),".\n";	
	print "\t\t\t\tBusiness Body Priority Time Stamp is ",Priority_Time_Stamp_Value(substr($payload, 110, 16)).".\n";	
	print "\t\t\t\tBusiness Body Trading System Time Stamp is ",Priority_Time_Stamp_Value(substr($payload, 126, 16)).".\n";
}

sub Stock_Status
{
	print "\t\t\t\tThis is Intraday message.\n";
	print "\t\t\t\tBusiness Message type is '",Business_message_type(hex $BusHdr{Msg_Type}),"'.\n";
	print "\t\t\t\tBusiness Body Symbol is ",pack("H18", substr($payload, 46, 18)),"\n";
	print "\t\t\t\tBusiness Body Stock State is ",Stock_State_Value(substr($payload, 64, 4)),"\n";	
	print "\t\t\t\tBusiness Body Trading System Time Stamp is ",Priority_Time_Stamp_Value(substr($payload, 68, 16)).".\n";
}

sub Stock_State_Value
{
	my $value = chr(hex(shift));
	return $value.' AuthorizedDelayed.' if($value eq 'AR');
	return $value.' InhibitedDelayed.' if($value eq 'IR');	
	return $value.' AuthorizedHalted.' if($value eq 'AS');	
	return $value.' InhibitedHalted.' if($value eq 'IS');	
	return $value.' AuthorizedFrozen' if($value eq 'AG');	
	return $value.' InhibitedFrozen.' if($value eq 'IG');
	return $value.' Authorized Price Movement Delayed.' if($value eq 'AE');	
	return $value.' Authorized Price Movement Frozen.' if($value eq 'AF');	
	return $value.' Inhibited Price Movement Delayed.' if($value eq 'IE');	
	return $value.' Inhibited Price Movement Frozen.' if($value eq 'IF');
	return $value.' Authorized.' if($value eq 'A');
	return $value.' Inhibited.' if($value eq 'I');
	return $value.' Wrong Value for Stock State.';
}

sub Trade_Report
{
	print "\t\t\t\tThis is Intraday message.\n";
	print "\t\t\t\tBusiness Message type is '",Business_message_type(hex $BusHdr{Msg_Type}),"'.\n";
	print "\t\t\t\tBusiness Body Symbol is ",pack("H18", substr($payload, 46, 18)),"\n";
	print "\t\t\t\tBusiness Body Trade Number is ",Number_N_Value(substr($payload, 64, 8)),"\n"; # unpack("h8", pack("H8", substr($payload, 64, 8)))
	print "\t\t\t\tBusiness Body Price is ",unpack("j16", pack("H16", substr($payload, 72, 16)))/1000000,".\n";
	print "\t\t\t\tBusiness Body Volume is ",unpack("j16", pack("H16",substr($payload, 88, 8))),".\n";
	print "\t\t\t\tBusiness Body Buy Broker Number is ",Number_N_Value(substr($payload, 96, 4)),"\n";
	print "\t\t\t\tBusiness Body Buy Order ID is ",unpack("j16", pack "H16", substr($payload, 100, 16)),".\n";
	print "\t\t\t\tBusiness Body Buy Display Volume is ",unpack("j16", pack("H16",substr($payload, 116, 8))),".\n";
	print "\t\t\t\tBusiness Body Sell Broker Number is ",Number_N_Value(substr($payload, 124, 4)),"\n";
	print "\t\t\t\tBusiness Body Sell Order ID is ",unpack("j16", pack "H16", substr($payload, 128, 16)),".\n";
	print "\t\t\t\tBusiness Body Sell Display Volume is ",unpack("j16", pack("H16",substr($payload, 144, 8))),".\n";
	print "\t\t\t\tBusiness Body Bypass is ",Bypass_Value(substr($payload, 152, 2)),"\n";
	my $date = unpack("j16", pack "H16", substr($payload, 154, 8)); 
	print "\t\t\t\tBusiness Body Trade Time Stamp is ",$date,".\n";
	print "\t\t\t\tBusiness Body Cross Type is ",Cross_Type_Value(substr($payload, 162, 2)),"\n";	
	print "\t\t\t\tBusiness Body Trading System Time Stamp is ",Priority_Time_Stamp_Value(substr($payload, 164, 16)).".\n";
}

sub Bypass_Value
{
	my $value = chr(hex(shift));
	return $value.' The order is a Bypass.' if($value eq 'Y');
	return $value.' The order is not a Bypass.' if($value eq 'N');
	return $value.' Wrong Value for Bypass.'
}

sub Cross_Type_Value
{
	my $value = chr(hex(shift));
	return $value.' Internal.' if($value eq 'I');
	return $value.' Basis.' if($value eq 'B');
	return $value.' Contingent (TSX Only).' if($value eq 'C');
	return $value.' Special Trading session (TSX Only).' if($value eq 'S');
	return $value.' VWAP – Volume Weighted Average Price (TSX Only).' if($value eq 'V');	
	return $value.' Wrong Value for Cross Type.'
}

sub Trade_Report_Terms
{
	print "\t\t\t\tThis is Intraday message.\n";
	print "\t\t\t\tBusiness Message type is '",Business_message_type(hex $BusHdr{Msg_Type}),"'.\n";
	print "\t\t\t\tBusiness Body Symbol is ",pack("H18", substr($payload, 46, 18)),"\n";
	print "\t\t\t\tBusiness Body Trade Number is ",unpack("h8", pack("H8", substr($payload, 64, 8))),"\n"; 
	print "\t\t\t\tBusiness Body Price is ",unpack("j16", pack("H16", substr($payload, 72, 16)))/1000000,".\n";
	print "\t\t\t\tBusiness Body Volume is ",unpack("j16", pack("H16",substr($payload, 88, 8))),".\n";
	print "\t\t\t\tBusiness Body Buy Broker Number is ",Number_N_Value(substr($payload, 96, 4)),"\n";
	print "\t\t\t\tBusiness Body Buy Order ID is ",unpack("j16", pack "H16", substr($payload, 100, 16)),".\n";
	print "\t\t\t\tBusiness Body Buy Display Volume is ",unpack("j16", pack("H16",substr($payload, 116, 8))),".\n";
	print "\t\t\t\tBusiness Body Sell Broker Number is ",Number_N_Value(substr($payload, 126, 4)),"\n";
	print "\t\t\t\tBusiness Body Sell Order ID is ",unpack("j16", pack "H16", substr($payload, 130, 16)),".\n";
	print "\t\t\t\tBusiness Body Sell Display Volume is ",unpack("j16", pack("H16",substr($payload, 146, 8))),".\n";
	my $date = unpack("j16", pack "H16", substr($payload, 154, 8)); 
	print "\t\t\t\tBusiness Body Trade Time Stamp is ",$date,".\n";
	print "\t\t\t\tBusiness Body Non Resident is ",Non_Resident_Value (substr($payload, 162, 2)),"\n"; 
	print "\t\t\t\tBusiness Body Settlement Terms is ",Settlement_Terms_Value (substr($payload, 164, 2)),"\n";
	print "\t\t\t\tBusiness Body Cross Type is ",Cross_Type_Value(substr($payload, 166, 2)),"\n";	
	print "\t\t\t\tBusiness Body Trading System Time Stamp is ",Priority_Time_Stamp_Value(substr($payload, 168, 16)).".\n";
}

sub Trade_Cancelled
{
	print "\t\t\t\tThis is Intraday message.\n";
	print "\t\t\t\tBusiness Message type is '",Business_message_type(hex $BusHdr{Msg_Type}),"'.\n";
	print "\t\t\t\tBusiness Body Symbol is ",pack("H18", substr($payload, 46, 18)),"\n";
	print "\t\t\t\tBusiness Body Trade Number is ",unpack("h8", pack("H8", substr($payload, 64, 8))),"\n"; 	
	print "\t\t\t\tBusiness Body Trading System Time Stamp is ",Priority_Time_Stamp_Value(substr($payload, 72, 16)).".\n";
}

sub Trade_Cancelled_Terms
{
	print "\t\t\t\tThis is Intraday message.\n";
	print "\t\t\t\tBusiness Message type is '",Business_message_type(hex $BusHdr{Msg_Type}),"'.\n";
	print "\t\t\t\tBusiness Body Symbol is ",pack("H18", substr($payload, 46, 18)),"\n";
	print "\t\t\t\tBusiness Body Trade Number is ",unpack("h8", pack("H8", substr($payload, 64, 8))),"\n";	
	print "\t\t\t\tBusiness Body Trading System Time Stamp is ",Priority_Time_Stamp_Value(substr($payload, 72, 16)).".\n";
}

sub Trade_Correction
{
	print "\t\t\t\tThis is  Intraday message.\n";
	print "\t\t\t\tBusiness Message type is '",Business_message_type(hex $BusHdr{Msg_Type}),"'.\n";
	print "\t\t\t\tBusiness Body Symbol is ",pack("H18", substr($payload, 46, 18)),"\n";
	print "\t\t\t\tBusiness Body Trade Number is ",unpack("h8", pack("H8", substr($payload, 64, 8))),".\n"; 
	print "\t\t\t\tBusiness Body Price is ",unpack("j16", pack("H16", substr($payload, 72, 16)))/1000000,".\n";
	print "\t\t\t\tBusiness Body Volume is ",unpack("j16", pack("H16",substr($payload, 88, 8))),".\n";
	print "\t\t\t\tBusiness Body Buy Broker Number is ",Number_N_Value(substr($payload, 96, 4)),".\n";
	print "\t\t\t\tBusiness Body Sell Broker Number is ",Number_N_Value(substr($payload, 100, 4)),".\n";
	print "\t\t\t\tBusiness Body Initiated By is ",substr($payload, 104, 2),".\n";
	print "\t\t\t\tBusiness Body Orig Trade Number is ",substr($payload, 106, 8),".\n"; 
	print "\t\t\t\tBusiness Body Bypass is ",Bypass_Value(substr($payload, 114, 2)),"\n";
	my $date = unpack("j16", pack "H16", substr($payload, 116, 8)); 
	print "\t\t\t\tBusiness Body Trade Time Stamp is ",$date,".\n";
	print "\t\t\t\tBusiness Body Cross Type is ",Cross_Type_Value(substr($payload, 124, 2)),"\n";	
	print "\t\t\t\tBusiness Body Trading System Time Stamp is ",Priority_Time_Stamp_Value(substr($payload, 126, 16)).".\n";	
}

sub Trade_Correction_Terms
{
	print "\t\t\t\tThis is  Intraday message.\n";
	print "\t\t\t\tBusiness Message type is '",Business_message_type(hex $BusHdr{Msg_Type}),"'.\n";
	print "\t\t\t\tBusiness Body Symbol is ",pack("H18", substr($payload, 46, 18)),"\n";
	print "\t\t\t\tBusiness Body Trade Number is ",unpack("h8", pack("H8", substr($payload, 64, 8))),".\n"; 
	print "\t\t\t\tBusiness Body Price is ",unpack("j16", pack("H16", substr($payload, 72, 16)))/1000000,".\n";
	print "\t\t\t\tBusiness Body Volume is ",unpack("j16", pack("H16",substr($payload, 88, 8))),".\n";
	print "\t\t\t\tBusiness Body Buy Broker Number is ",Number_N_Value(substr($payload, 96, 4)),".\n";
	print "\t\t\t\tBusiness Body Sell Broker Number is ",Number_N_Value(substr($payload, 100, 4)),".\n";
	print "\t\t\t\tBusiness Body Initiated By is ",substr($payload, 104, 2),".\n";
	print "\t\t\t\tBusiness Body Orig Trade Number is ",substr($payload, 106, 8),".\n";
	my $date = unpack("j16", pack "H16", substr($payload, 114, 8)); 
	print "\t\t\t\tBusiness Body Trade Time Stamp is ",$date,".\n";
	print "\t\t\t\tBusiness Body Non Resident is ",Non_Resident_Value (substr($payload, 122, 2)),"\n";
	print "\t\t\t\tBusiness Body Settlement Terms is ",Settlement_Terms_Value (substr($payload, 124, 2)),"\n"; 
	print "\t\t\t\tBusiness Body Settlement Date is ",substr($payload, 126, 8),".\n";
	print "\t\t\t\tBusiness Body Cross Type is ",Cross_Type_Value(substr($payload, 134, 2)),"\n";	
	print "\t\t\t\tBusiness Body Trading System Time Stamp is ",Priority_Time_Stamp_Value(substr($payload, 136, 16)).".\n";	
}

sub Admin_header
{
	Heartbeat() if($AdmHdr{Msg_Type}==30);
	Login_Request() if($AdmHdr{Msg_Type}==31);
	Login_Response() if($AdmHdr{Msg_Type}==32);
	Logout() if($AdmHdr{Msg_Type}==33);
	Ack() if($AdmHdr{Msg_Type}==34);
	Replay_Request() if($AdmHdr{Msg_Type}==35);
	Sequence_Jump() if($AdmHdr{Msg_Type}==36);
	Reserved() if($AdmHdr{Msg_Type}==37);
	Operation() if($AdmHdr{Msg_Type}==38);
	Reject() if($AdmHdr{Msg_Type}==39);
	return undef;	
}

sub Heartbeat
{
	my $counter = 0;
	print "\n";
	print "\t\t\t\tAdmin Header Message Type Heartbeat.\n";
	print "\t\t\t\tAdmin Header Message length ",hex(unpack("h2", pack("h2", $AdmHdr{Msg_Length}))),".\n";
	print "\t\t\t\tAdmin Msg Type ",hex(unpack("h2", pack("h2", $AdmHdr{Msg_Type}))),".\n";
	print "\t\t\t\tAdmin ID ",hex(unpack("h2", pack("h2", $AdmHdr{Admin_ID}))),".\n";
	print "\t\t\t\tHb Interval ",hex(unpack("h2", pack("h2", $AdmHdr{Hb_Interval}))),".\n";	
	print "\t\t\t\tStart AdmBdy:\n";
	while($counter < $xmt{Num_Body})
		{			
			print "\t\t\t\t",$counter+1," Source ID ",hex(unpack("h2", pack("h2", substr($payload, 34+$counter*16, 2)))),".\n";
			print "\t\t\t\t",$counter+1," Stream ID ",hex(unpack("h4", pack("h4", substr($payload, 36+$counter*16, 4)))),".\n";
			print "\t\t\t\t",$counter+1," Sequence-0 ", substr($payload, 40+$counter*16, 2),".\n";
			print "\t\t\t\t",$counter+1," Sequence-1 ", substr($payload, 42+$counter*16, 8),".\n";
			++$counter;			
		}
}

sub Login_Request
{
	print "\n";
	print "\t\t\t\tAdmin Header Message Type Login Request.\n";
	print "\t\t\t\tAdmin Header Message length ",hex(unpack("h2", pack("h2", $AdmHdr{Msg_Length}))),".\n";
	print "\t\t\t\tAdmin Msg Type ",hex(unpack("h2", pack("h2", $AdmHdr{Msg_Type}))),".\n";
	print "\t\t\t\tAdmin ID ",hex(unpack("h2", pack("h2", $AdmHdr{Admin_ID}))),".\n";
	print "\t\t\t\tHb Interval ",hex(unpack("h2", pack("h2", $AdmHdr{Hb_Interval}))),".\n";	
	print "\t\t\t\tReplay Win Size ",hex(unpack("h2", pack("h2", $AdmHdr{Replay_Win_Size}))),".\n";	
	print "\t\t\t\tReplay Win Num ",hex(unpack("h2", pack("h2", $AdmHdr{Replay_Win_Num}))),".\n";
	print "\t\t\t\tCredits ",hex(unpack("h2", pack("h2", $AdmHdr{Login_Request_Credits}))),".\n";	
}

sub Login_Response
{
	print "\n";
	print "\t\t\t\tAdmin Header Message Type Login Response.\n";
	print "\t\t\t\tAdmin Header Message length ",hex(unpack("h2", pack("h2", $AdmHdr{Msg_Length}))),".\n";
	print "\t\t\t\tAdmin Msg Type ",hex(unpack("h2", pack("h2", $AdmHdr{Msg_Type}))),".\n";
	print "\t\t\t\tAdmin ID ",hex(unpack("h2", pack("h2", $AdmHdr{Admin_ID}))),".\n";
	print "\t\t\t\tHb Interval ",hex(unpack("h2", pack("h2", $AdmHdr{Hb_Interval}))),".\n";	
	print "\t\t\t\tReplay Win Size ",hex(unpack("h2", pack("h2", $AdmHdr{Replay_Win_Size}))),".\n";	
	print "\t\t\t\tReplay Win Num ",hex(unpack("h2", pack("h2", $AdmHdr{Replay_Win_Num}))),".\n";
	print "\t\t\t\tReplay Win ",hex(unpack("h2", pack("h2", $AdmHdr{Replay_Win}))),".\n";
	print "\t\t\t\tCredits ",hex(unpack("h2", pack("h2", $AdmHdr{Login_Response_Credits}))),".\n";
}

sub Logout
{
	print "\n";
	print "\t\t\t\tAdmin Header Message Type Logout.\n";
	print "\t\t\t\tAdmin Header Message length ",hex(unpack("h2", pack("h2", $AdmHdr{Msg_Length}))),".\n";
	print "\t\t\t\tAdmin Msg Type ",hex(unpack("h2", pack("h2", $AdmHdr{Msg_Type}))),".\n";
	print "\t\t\t\tAdmin ID ",hex(unpack("h2", pack("h2", $AdmHdr{Admin_ID}))),".\n";
}

sub Ack
{
	print "\n";
	print "\t\t\t\tAdmin Header Message Type Ack.\n";
	print "\t\t\t\tAdmin Header Message length ",hex(unpack("h2", pack("h2", $AdmHdr{Msg_Length}))),".\n";
	print "\t\t\t\tAdmin Msg Type ",hex(unpack("h2", pack("h2", $AdmHdr{Msg_Type}))),".\n";
	print "\t\t\t\tAdmin ID ",hex(unpack("h2", pack("h2", $AdmHdr{Admin_ID}))),".\n";
	print "\t\t\t\tAck Admin Bdy ",substr($payload, 30, hex(unpack("h2", pack("h2", $AdmHdr{Msg_Length}))) - 8 ),".\n";
}

sub Replay_Request
{
	my $counter = 0;
	print "\n";
	print "\t\t\t\tAdmin Header Message Type Replay Request.\n";
	print "\t\t\t\tAdmin Header Message length ",hex(unpack("h2", pack("h2", $AdmHdr{Msg_Length}))),".\n";
	print "\t\t\t\tAdmin Msg Type ",hex(unpack("h2", pack("h2", $AdmHdr{Msg_Type}))),".\n";
	print "\t\t\t\tAdmin ID ",hex(unpack("h2", pack("h2", $AdmHdr{Admin_ID}))),".\n";
	print "\t\t\t\tSession ID ",hex(unpack("h8", pack("h8", $AdmHdr{Session_ID}))),".\n";
	print "\t\t\t\tStart AdmBdy:\n";
	while($counter < $xmt{Num_Body})
		{			
			print "\t\t\t\t",$counter+1," Source ID ",hex(unpack("h2", pack("h2", substr($payload, 38+$counter*24, 2)))),".\n";
			print "\t\t\t\t",$counter+1," Stream ID ",hex(unpack("h4", pack("h4", substr($payload, 40+$counter*24, 4)))),".\n";
			print "\t\t\t\t",$counter+1," Sequence-0 ", substr($payload, 44+$counter*24, 2),".\n";
			print "\t\t\t\t",$counter+1," Sequence-1 Start", substr($payload, 46+$counter*24, 8),".\n";
			print "\t\t\t\t",$counter+1," Sequence-1 End", substr($payload, 54+$counter*24, 8),".\n";
			++$counter;			
		}
}

sub Sequence_Jump
{
	my $counter = 0;
	print "\n";
	print "\t\t\t\tAdmin Header Message Type Sequence Jump.\n";
	print "\t\t\t\tAdmin Header Message length ",hex(unpack("h2", pack("h2", $AdmHdr{Msg_Length}))),".\n";
	print "\t\t\t\tAdmin Msg Type ",hex(unpack("h2", pack("h2", $AdmHdr{Msg_Type}))),".\n";
	print "\t\t\t\tAdmin ID ",hex(unpack("h2", pack("h2", $AdmHdr{Admin_ID}))),".\n";
	print "\t\t\t\tReason Code is ",hex(unpack("h2", pack("h2", $AdmHdr{Sequence_Jump_Reason_Code}))),". Meaning ",Seq_jump_reas_code($AdmHdr{Sequence_Jump_Reason_Code}),"\n";
	print "\t\t\t\tStart AdmBdy:\n";
	while($counter < $xmt{Num_Body})
		{			
			print "\t\t\t\t",$counter+1," Source ID ",hex(unpack("h2", pack("h2", substr($payload, 32+$counter*24, 2)))),".\n";
			print "\t\t\t\t",$counter+1," Stream ID ",hex(unpack("h4", pack("h4", substr($payload, 34+$counter*24, 4)))),".\n";
			print "\t\t\t\t",$counter+1," Sequence-0 ", substr($payload, 38+$counter*24, 2),".\n";
			print "\t\t\t\t",$counter+1," Sequence-1 Current", substr($payload, 40+$counter*24, 8),".\n";
			print "\t\t\t\t",$counter+1," Sequence-1 New", substr($payload, 48+$counter*24, 8),".\n";
			++$counter;			
		}
}

sub Seq_jump_reas_code
{
	my $value =  shift;
	return 'Do not resend' if( $value == 1 );
	return ' No longer available' if( $value == 2 );
	return 'Disaster' if( $value == 3 );
	return undef;	
}

sub Reserved
{
	print "\n";
	print "\t\t\t\tAdmin Header Message Type Reserved.\n";
}

sub Operation
{
	print "\n";
	print "\t\t\t\tAdmin Header Message Type Operation.\n";
	print "\t\t\t\tAdmin Header Message length ",hex(unpack("h2", pack("h2", $AdmHdr{Msg_Length}))),".\n";
	print "\t\t\t\tAdmin Msg Type ",hex(unpack("h2", pack("h2", $AdmHdr{Msg_Type}))),".\n";
	print "\t\t\t\tAdmin ID ",hex(unpack("h2", pack("h2", $AdmHdr{Admin_ID}))),".\n";
	print "\t\t\t\tOperation Code is ",hex(unpack("h2", pack("h2", $AdmHdr{Sequence_Jump_Reason_Code}))),". Meaning ",Operation_Code($AdmHdr{Sequence_Jump_Reason_Code}),"\n";
	print "\t\t\t\tOperation message ",pack("H200", $AdmHdr{Operation_message}),".\n";	
}


sub Operation_Code
{
	my $value =  shift;
	return 'Information' if( $value == 0 );
	return 'Warning' if( $value == 1 );
	return ' Alert' if( $value == 2 );
	return 'Next business message to be dropped.' if( $value == 3 );
	return undef;
}

sub Reject
{
	print "\n";
	print "\t\t\t\tAdmin Header Message Type Reject.\n";
	print "\t\t\t\tAdmin Header Message length ",hex(unpack("h2", pack("h2", $AdmHdr{Msg_Length}))),".\n";
	print "\t\t\t\tAdmin Msg Type ",hex(unpack("h2", pack("h2", $AdmHdr{Msg_Type}))),".\n";
	print "\t\t\t\tAdmin ID ",hex(unpack("h2", pack("h2", $AdmHdr{Admin_ID}))),".\n";
	print "\t\t\t\tReject Code is ",hex(unpack("h2", pack("h2", $AdmHdr{Reject_Code}))),". Meaning ",Reject_Code($AdmHdr{Reject_Code}),"\n";
	print "\t\t\t\tReject Subcode is ",hex(unpack("h2", pack("h2", $AdmHdr{Reject_Subcode})))," Meaning ",Reject_Subcode($AdmHdr{Reject_Subcode}),".\n";
	print "\t\t\t\tReject message ",hex(unpack("h60", pack("h60", $AdmHdr{Reject_message}))),".\n";	
}


sub Reject_Code
{
	my $value =  shift;
	return ' Information' if( $value == 0 );
	return 'Warning' if( $value == 1 );
	return 'Critical' if( $value == 2 );
	return 'Fatal' if( $value == 3 );
	return undef;
}

sub Reject_Subcode
{
	my $value =  shift;
	return 'Invalid syntax' if( $value == 1 );
	return 'Invalid session states/conditions' if( $value == 2 );
	return 'Invalid values' if( $value == 3 );
	return 'Function not implemented' if( $value == 4 );
	return 'Function not allowed' if( $value == 5 );
	return 'Function temporarily not available, but retryable' if( $value == 6 );
	return 'Message temporarily not available, but retryable' if( $value == 7 );
	return 'Duplicate request/message' if( $value == 8 );
	return 'Others, see Message' if( $value == 9 );
	return undef;
}

sub check_Alphanumeric
{
	my $value = shift;		
	return 1 if( 20 <  $value and $value < 126 );
	return 0;
}
sub check_Numeric
{
	my $value = shift;		
	return 1 if( 30 <  $value and $value < 39 );
	return 0;
}
