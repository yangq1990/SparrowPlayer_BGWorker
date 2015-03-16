package
{
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.events.ProgressEvent;
	import flash.events.SecurityErrorEvent;
	import flash.net.URLRequest;
	import flash.net.URLStream;
	import flash.system.MessageChannel;
	import flash.system.Security;
	import flash.system.Worker;
	import flash.utils.ByteArray;
	
	/**
	 * 播放加密视频时，在后台加载和解密视频字节数据的线程
	 * 视频完全被加载到内存后，此线程被主线程销毁
	 * @author yangq1990
	 * 
	 */	
	public class SparrowPlayer_BGWorker extends Sprite
	{
		/** 命令通道 **/
		private var _cmdChannel:MessageChannel;
		/** 状态通道 **/
		private var _stateChannel:MessageChannel;
		/** 与主worker共享的内存数据 **/
		private var _data:ByteArray;
		/** URLStream提供了对字节层面的访问 **/
		private var _urlStream:URLStream;
		private var _counter:Number = 0;
		/** 未加密的字节数据 **/
		private var _omittedLength:Number = 0;
		/** 加密算法种子 **/
		private var _seed:int = 0;		
		
		public function SparrowPlayer_BGWorker()
		{
			init();
		}
		
		private function init():void
		{
			try
			{
				Security.allowDomain("*");
				_cmdChannel = Worker.current.getSharedProperty("incomingCmdChannel") as MessageChannel;
				_cmdChannel.addEventListener(Event.CHANNEL_MESSAGE, cmdChannelMsgHandler);
				
				_data = Worker.current.getSharedProperty("data") as ByteArray;
				
				_stateChannel = Worker.current.getSharedProperty('bgWokerStateChannel') as MessageChannel;
				_stateChannel.send(['bg_worker_ready']); //tell main worker that child worker is ready
			}
			catch(err:Error)
			{
				trace(err.getStackTrace());
			}			
		}
		
	
		private function cmdChannelMsgHandler(event:Event):void
		{
			if (!_cmdChannel.messageAvailable)
				return;
			
			var message:Array = _cmdChannel.receive() as Array;
			if(message != null)
			{
				switch(message[0])
				{
					case "doLoad":
						_omittedLength = message[2];
						_seed = message[3];						
						_urlStream = new URLStream();
						_urlStream.addEventListener(SecurityErrorEvent.SECURITY_ERROR, securityErrorHandler);
						_urlStream.addEventListener(IOErrorEvent.IO_ERROR, ioErrorHandler);
						_urlStream.addEventListener(ProgressEvent.PROGRESS,progressHandler);  
						_urlStream.addEventListener(Event.COMPLETE,completeHnd);  
						_urlStream.addEventListener(Event.OPEN, openHandler);
						_urlStream.load(new URLRequest(message[1]));
						break;
					default:
						break;
				}
			}
			else
			{
				_stateChannel.send(["error", "解密时传入的参数不正确"]);
			}
		}
		
		/** 开始加载 **/
		private function openHandler(evt:Event):void
		{
			_stateChannel.send(["start_load_media"]);
		}
		
		/** security error  **/
		private function securityErrorHandler(evt:SecurityErrorEvent):void
		{
			_stateChannel.send(["error", evt.toString()]);
		}		
		
		private function ioErrorHandler(evt:IOErrorEvent):void
		{
			_stateChannel.send(["error", evt.toString()]);
		}		
		
		/** 加载加密视频中 **/
		private function progressHandler(evt:ProgressEvent):void
		{				
			var bytes:ByteArray = new ByteArray();
			_urlStream.readBytes(bytes);
			
			var value:int;
			var streamBytes:ByteArray = new ByteArray();
			streamBytes.shareable = true;
			while(bytes.bytesAvailable)
			{
				value = bytes.readByte();
				if(_counter >= _omittedLength)
				{
					value -= 128;
				}
				streamBytes.writeByte(value);
				_data.writeByte(value);
				_counter += 1;				
			}
			_stateChannel.send(["load_media_progress", evt.bytesLoaded/evt.bytesTotal, evt.bytesTotal, streamBytes]);
		}  
		
		/** 加载完成 **/
		private function completeHnd(e:Event):void
		{					
			_stateChannel.send(["load_media_complete"]);
			destroyUrlStream();
		} 
		
		/** 清理urlstream **/
		private function destroyUrlStream():void
		{			
			if(_urlStream)
			{
				_urlStream.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, securityErrorHandler);
				_urlStream.removeEventListener(IOErrorEvent.IO_ERROR, ioErrorHandler);
				_urlStream.removeEventListener(ProgressEvent.PROGRESS,progressHandler);  
				_urlStream.removeEventListener(Event.COMPLETE,completeHnd);  
				_urlStream.removeEventListener(Event.OPEN, openHandler);
				_urlStream.close();			
				_urlStream = null;
			}	
		}
	}
}