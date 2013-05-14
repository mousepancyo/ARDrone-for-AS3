package jp.digifie.ardrone
{
  import flash.display.BitmapData;
	import flash.display.DisplayObject;
	import flash.display.Sprite;
	import flash.events.DatagramSocketDataEvent;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IOErrorEvent;
	import flash.events.MouseEvent;
	import flash.geom.Rectangle;
	import flash.net.DatagramSocket;
	import flash.utils.ByteArray;
	import flash.utils.Endian;
	
	
	/**
	 * 
	 * @author mousepancyo (LLC DigiFie)
	 */
	public class ARDroneForAS3 extends Sprite
	{
		private const CR:String = "\r";
		
		private var _droneIP:String;
		private var _commandPort:int = 5556;
		private var _navigationPort:int = 5554;
		
		private var _commandSock:DatagramSocket;
		private var _navigationSock:DatagramSocket;
		
		public var seq:int = 1;
		private var _speed:Number = .05; // 0.01f - 1.0f;
		private var _buffer:ByteArray = new ByteArray();
		
		private var _isLanding:Boolean;
		private var _isContinuance:Boolean;
		private var _command:String;
		
		private var _parser:NavigationDataParser = new NavigationDataParser();
		
		public var batteryPercentage:int;
		public var pitch:Number = 0;
		public var roll:Number = 0;
		public var yaw:Number = 0;
		public var altitude:int;
		public var vx:Number = 0;
		public var vy:Number = 0;
		public var vz:Number = 0;
		
		public var videoImage:BitmapData;
		
		
		public function ARDroneForAS3( droneIP:String = "192.168.1.1" )
		{
			_droneIP = droneIP;
			setup();
		}
		
		
		
		// -------------- Setup ----------------------------------------------- /
		public function setup():void
		{
			// Socket
			_commandSock = new DatagramSocket();
			_navigationSock = new DatagramSocket();
			_commandSock.addEventListener( IOErrorEvent.IO_ERROR, onConnectError ); // Error Handling.
			_navigationSock.addEventListener( IOErrorEvent.IO_ERROR, onConnectError ); // Error Handling.
			
			try
			{
				_commandSock.connect( _droneIP, _commandPort );
				_navigationSock.connect( _droneIP, _navigationPort );
			}
			catch ( e:Error )
			{
				trace( e );
			}
			
			// Recever
			_navigationSock.addEventListener( DatagramSocketDataEvent.DATA, rcvNaviData );
			_navigationSock.receive();
			
			// Connect Check
			trace( "ctrlSocket connected:", _commandSock.connected );
			trace( "navigationSocket connected:", _navigationSock.connected );
			
			// init
			_isLanding = true;
			
			// IO Error
			function onConnectError( e:IOErrorEvent ):void
			{
				trace( e.target, e );
			}
		}
		
		
		// -------------- Start ----------------------------------------------- /
		public function startARDrone():void
		{	
			initARDrone();
			
			// NaviData
			ticklePort( _navigationSock );
			enableDemoData();
			ticklePort( _navigationSock );
			sendControlAck();
		}
		
		
		// -------------- Stop ----------------------------------------------- /
		public function stopARDrone():void
		{
			moveStop();
			landing();
			removeEventListener( Event.ENTER_FRAME, update );
			//
			_commandSock.close();
			_navigationSock.close();
		}
		
		
		// -------------- Update ----------------------------------------------- /
		private function update( e:Event ):void
		{
			// Command
			if ( seq % 5 == 0 ) //<2000ms
			{
				sendCommand( "AT*COMWDG=" + ( seq++ ), _commandSock);
			}
			else
			{
				if ( _command != null )
				{
					sendCommand( _command, _commandSock );
					if ( !_isContinuance )
					{
						_command = null;
					}
				}
				else
				{
					if ( _isLanding )
					{
						sendCommand( "AT*PCMD=" + ( seq++ ) + ",1,0,0,0,0" + CR + "AT*REF=" + ( seq++ ) + ",290717696", _commandSock );
					}
					else
					{
						sendCommand( "AT*PCMD=" + ( seq++ ) + ",1,0,0,0,0" + CR + "AT*REF=" + ( seq++ ) + ",290718208", _commandSock );
					}
				}
			}
			
			// NavData
			batteryPercentage = _parser.batteryPercentage;
			pitch = _parser.pitch;
			roll = _parser.roll;
			yaw = _parser.yaw;
			altitude = _parser.altitude;
			vx = _parser.vx;
			vy = _parser.vy;
			vz = _parser.vz;
			
			dispatchEvent( new Event( "state_change" ) );
		}
		
		
		// -------------- Recever ----------------------------------------------- /
		
		// CommandSocket
		private function onData( e:DatagramSocketDataEvent ):void
		{
			//trace( e.data );
		}
		
		// NavigationSocket
		private function rcvNaviData( e:DatagramSocketDataEvent ):void
		{
			e.data.endian = Endian.LITTLE_ENDIAN;
			_parser.parseNavData( e.data );
		}
		
		
		
		
		// -------------- Send Command ----------------------------------------------- /
		private function sendCommand( command:String, socket:DatagramSocket ):void
		{
			var ba:ByteArray = new ByteArray();
			ba.writeUTFBytes( command + CR );
			try
			{
				socket.send( ba, 0, ba.length, null, 0 );
			}
			catch ( e:Error )
			{
				trace( e, command );
			}
		}
		
		
		// -------------- Init ARDrone ----------------------------------------------- /
		private function initARDrone():void
		{
			sendCommand( "AT*CONFIG=" + ( seq++ ) + ",\"general:navdata_demo\",\"TRUE\"" + CR + "AT*FTRIM=" + ( seq++ ), _commandSock); //1
			sendCommand( "AT*PMODE=" + ( seq++ ) + ",2" + CR + "AT*MISC=" + ( seq++ ) + ",2,20,2000,3000" + CR + "AT*FTRIM=" + ( seq++ ) + CR + "AT*REF=" + ( seq++ ) + ",290717696", _commandSock ); //2-5
			sendCommand( "AT*PCMD=" + ( seq++ ) + ",1,0,0,0,0" + CR + "AT*REF=" + ( seq++ ) + ",290717696" + CR + "AT*COMWDG=" + ( seq++ ), _commandSock); //6-8
			sendCommand( "AT*PCMD=" + ( seq++ ) + ",1,0,0,0,0" + CR + "AT*REF=" + ( seq++ ) + ",290717696" + CR + "AT*COMWDG=" + ( seq++ ), _commandSock); //6-8
			sendCommand( "AT*FTRIM=" + ( seq++ ), _commandSock);
			trace( "initialized complete" );
			//
			addEventListener( Event.ENTER_FRAME, update );
		}
		
		
		// -------------- Command ----------------------------------------------- /
		
		public function enableDemoData():void
		{
			_command = "AT*CONFIG="+(seq++) + ",\"general:navdata_demo\",\"TRUE\""+CR+"AT*FTRIM="+(seq++);
			_isContinuance = false;
		}
		
		public function sendControlAck():void
		{
			_command = "AT*CTRL="+(seq++) + ",0";
			_isContinuance = false;
		}
		
		public function enableVideoData():void
		{
			_command = "AT*CONFIG="+(seq++) + ",\"general:video_enable\",\"TRUE\"" + CR + "AT*FTRIM=" + (seq++);
			_isContinuance=false;
		}
		
		public function disableAutomaticVideoBitrate():void
		{
			_command = "AT*CONFIG=" + (seq++) + ",\"video:bitrate_ctrl_mode\",\"0\"";
			_isContinuance = false;
		}

		
		// Reset
		public function reset():void
		{
			_command = "AT*REF=" + ( seq++ ) + ",290717952";
			_isContinuance = true;
		}
		
		// Takeoff
		public function takeoff():void
		{
			_command = "AT*REF=" + ( seq++ ) + ",290718208";
			_isLanding = false;
		}
		
		// Landing
		public function landing():void
		{
			_command = "AT*REF=" + ( seq++ ) + ",290717696";
			_isLanding = true;
		}
		
		// Move Stop
		public function moveStop():void
		{
			_command = "AT*PCMD=" + ( seq++ ) + ",1,0,0,0,0";
			_isContinuance = true;
		}
		
		// Left Turn
		public function turnLeft():void
		{
			_command = "AT*PCMD=" + ( seq++ ) + ",1,0,0,0," + intOfFloat( -_speed ) + CR + "AT*REF=" + ( seq++ ) + ",290718208";
			_isContinuance = true;
		}
		
		// Right Turn
		public function turnRight():void
		{
			_command = "AT*PCMD=" + ( seq++ ) + ",1,0,0,0," + intOfFloat( _speed ) + CR + "AT*REF=" + ( seq++ ) + ",290718208";
			_isContinuance = true;
		}
		
		// Right and Left Trun
		public function turn( dx:Number ):void
		{
			var sx:int = intOfFloat( dx );
			_command = "AT*PCMD=" + ( seq++ ) + ",1,0,0,0," + sx + CR + "AT*REF=" + ( seq++ ) + ",290718208";
			_isContinuance = true;
		}
		
		// Up
		public function up():void
		{
			_command = "AT*PCMD=" + (seq++) + ",1," + intOfFloat(0) + "," + intOfFloat(0) + "," + intOfFloat( _speed ) + "," +intOfFloat(0) + CR + "AT*REF="+(seq++)+",290718208";
			_isContinuance = true;
		}
		
		// Down
		public function down():void
		{
			_command = "AT*PCMD=" + (seq++) + ",1," + intOfFloat(0) + "," + intOfFloat(0) + "," + intOfFloat( -_speed ) + "," +intOfFloat(0) + CR + "AT*REF="+(seq++)+",290718208";
			_isContinuance = true;
		}
		
		// Up and Down
		public function upDown( dy:Number ):void
		{
			var sy:int = intOfFloat( dy );
			_command = "AT*PCMD=" + (seq++) + ",1," + intOfFloat(0) + "," + intOfFloat(0) + "," + ( -sy ) + "," +intOfFloat(0) + CR + "AT*REF="+(seq++)+",290718208";
			_isContinuance = true;
		}
		
		// Move Left
		public function moveLeft():void
		{
			_command = "AT*PCMD=" + ( seq++ ) + ",1," + intOfFloat( -_speed ) + ",0,0,0" + CR + "AT*REF=" + ( seq++ ) + ",290718208";
			_isContinuance = true;
		}
		
		// Move Right
		public function moveRight():void
		{
			_command = "AT*PCMD=" + ( seq++ ) + ",1," + intOfFloat( _speed ) + ",0,0,0" + CR + "AT*REF=" + ( seq++ ) + ",290718208";
			_isContinuance = true;
		}
		
		// move Fwd
		public function moveFwd():void
		{
			_command = "AT*PCMD=" + ( seq++ ) + ",1,0," + intOfFloat( -_speed ) + ",0,0" + CR + "AT*REF=" + ( seq++ ) + ",290718208";
			_isContinuance = true;
		}
		
		// move Back
		public function moveBack():void
		{
			_command = "AT*PCMD=" + ( seq++ ) + ",1,0," + intOfFloat( _speed ) + ",0,0" + CR + "AT*REF=" + ( seq++ ) + ",290718208";
			_isContinuance = true;
		}
		
		// move All Direction
		public function moveAllDirection( dx:Number, dy:Number ):void
		{
			var sx:int = intOfFloat( dx );
			var sy:int = intOfFloat( dy );
			_command = "AT*PCMD=" + ( seq++ ) + ",1," + sx + "," + sy + ",0,0" + CR + "AT*REF=" + ( seq++ ) + ",290718208";
			_isContinuance = true;
		}
		
		
		// -------------- float(Number) to intiger ----------------------------------------------- /
		private function intOfFloat( n:Number ):int
		{
			_buffer.clear();
			_buffer.writeFloat( n );
			//
			_buffer.position = 0;
			return _buffer.readInt();
		}
		
		
		private function ticklePort( sock:DatagramSocket ):void
		{
			var buf:ByteArray = new ByteArray();
			buf.writeByte(0x01);
			buf.writeByte(0x00);
			buf.writeByte(0x00);
			buf.writeByte(0x00);
			try
			{
				sock.send( buf, 0, buf.length, null, 0 );
			}
			catch ( e:Error )
			{
				trace( e );
			}
			
		}
		
		
		// -------------- Getter ----------------------------------------------- /
		public function get isLanding():Boolean
		{
			return _isLanding;
		}
		
	}
}
