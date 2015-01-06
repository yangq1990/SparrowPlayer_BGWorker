package
{
	import com.xinguoedu.utils.DecryptUtil;
	
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.system.MessageChannel;
	import flash.system.Worker;
	import flash.utils.ByteArray;
	
	public class SparrowPlayer_BGWorker extends Sprite
	{
		/** 命令通道 **/
		private var _cmdChannel:MessageChannel;
		/** 状态通道 **/
		private var _stateChannel:MessageChannel;
		/** 与主worker共享的内存数据 **/
		private var _data:ByteArray;
		
		public function SparrowPlayer_BGWorker()
		{
			init();
		}
		
		private function init():void
		{
			try
			{
				_cmdChannel = Worker.current.getSharedProperty("incomingCmdChannel") as MessageChannel;
				_cmdChannel.addEventListener(Event.CHANNEL_MESSAGE, cmdChannelMsgHandler);
				
				_data = Worker.current.getSharedProperty("data") as ByteArray;
				
				_stateChannel = Worker.current.getSharedProperty('bgWokerStateChannel') as MessageChannel;
				_stateChannel.send('child_worker_ready'); //tell main worker that child worker is ready
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
			
			if (message != null && message[0] == "start")
			{
				try
				{
					DecryptUtil.decrypt(_data, message[1], message[2]);
					_stateChannel.send(['decryption_success']); //tell main worker that decryption is successful
				}
				catch(err:Error)
				{
					_stateChannel.send('解密数据时出错');
				}
			}
			else
			{
				_stateChannel.send('参数不正确');
			}
		}
	}
}