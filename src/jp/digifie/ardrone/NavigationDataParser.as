package jp.digifie.ardrone
{
  import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.utils.ByteArray;
	import flash.utils.Endian;
	
	
	/**
	 * 
	 * @author mousepancyo (LLC DigiFie)
	 */
	public class NavigationDataParser
	{
		private var _lastSequenceNumber:Number = 1;
		
		public var batteryPercentage:int;
		public var pitch:Number = 0;
		public var roll:Number = 0;
		public var yaw:Number = 0;
		public var altitude:int;
		public var vx:Number = 0;
		public var vy:Number = 0;
		public var vz:Number = 0;
		
		
		public function NavigationDataParser()
		{
		}
		
		public function parseNavData( buffer:ByteArray ):void
		{
			buffer.endian = Endian.LITTLE_ENDIAN;
			var magic:int = buffer.readInt();
			var state:int = buffer.readInt();
			var sequence:Number = buffer.readInt() & 0xFFFFFFFF;
			var vision:int = buffer.readInt();
			
			if( sequence <= _lastSequenceNumber && sequence != 1 )
			{
				return;
			}
			_lastSequenceNumber = sequence;
			
			if( buffer.position < buffer.length )
			{	
				var tag:int = buffer.readShort() & 0xFFFF;
				var payloadSize:int = (buffer.readShort() & 0xFFFF)-4;
				
				var controlState:int = buffer.readInt();
				
				batteryPercentage = buffer.readInt();
				pitch = buffer.readFloat()/1000;
				roll = buffer.readFloat()/1000;
				yaw = buffer.readFloat()/1000;
				altitude = buffer.readInt();
				vx = buffer.readFloat();
				vy = buffer.readFloat();
				vz = buffer.readFloat();
				
				// trace("battery:", batteryPercentage, "/ pitch:", pitch, "/ roll:", roll, "/ yaw:", yaw, "/ altitude:", altitude, "/ dist:", vx, vy, vz);
				
			}
		}
		
	}
}
