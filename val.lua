----------------------------------------------------
---- Large-scale deep learning framework -----------
---- This script evaluates a given network. --------
---- This script is independent from any tasks. ----
---- Author: Donggeun Yoo, KAIST. ------------------
------------ dgyoo@rcv.kaist.ac.kr -----------------
----------------------------------------------------
local val = {  }
val.inputs = torch.CudaTensor(  )
val.labels = torch.CudaTensor(  )
val.netTimer = torch.Timer(  )
val.dataTimer = torch.Timer(  )
function val.setOption( opt, numBatchVal )
	assert( numBatchVal > 0 )
	assert( numBatchVal % 1 == 0 )
	assert( opt.batchSize > 0 )
	assert( opt.pathValLog:match( '(.+).log$' ):len(  ) > 0 )
	val.batchSize = opt.batchSize
	val.pathValLog = opt.pathValLog
	val.epochSize = numBatchVal
	if opt.net == 'siamese' then
		val.inputs = {
			torch.CudaTensor(),
			torch.CudaTensor(),
			torch.CudaTensor()
		}
		val.dirRoot = opt.dirRoot
	end
end
function val.setModel( modelSet )
	val.model = modelSet.model
	val.criterion = modelSet.criterion
end
function val.setDonkey( donkeys )
	val.donkeys = donkeys
end
function val.setFunction( getBatch, evalBatch )
	val.getBatch = getBatch
	val.evalBatch = evalBatch
end
function val.evaluate( epoch )
	-- Initialization.
	local valLogger = io.open( val.pathValLog, 'a' )
	local epochTimer = torch.Timer(  )
	local getBatch = val.getBatch
	local valBatch = val.evaluateBatch
	val.epoch = epoch
	val.evalEpoch = 0
	val.lossEpoch = 0
	val.batchNumber = 0
	-- Do the job.
	val.print( string.format( 'Validation epoch %d.', epoch ) )
	cutorch.synchronize(  )
	val.model:evaluate(  )
	for b = 1, val.epochSize do
		local s = ( b - 1 ) * val.batchSize + 1
		val.donkeys:addjob(
			function(  )
				return getBatch( s )
			end, -- Job callback.
			function( x, y )
				valBatch( x, y )
			end -- End callback.
		)
	end
	val.donkeys:synchronize(  )
	cutorch.synchronize(  )
	val.evalEpoch = val.evalEpoch / val.epochSize
	val.lossEpoch = val.lossEpoch / val.epochSize
	val.print( string.format( 'Epoch %d, time %.2fs, avg loss %.4f, eval %.4f', 
		epoch, epochTimer:time(  ).real, val.lossEpoch, val.evalEpoch ) )
	valLogger:write( string.format( '%03d %.4f %.4f\n', epoch, val.lossEpoch, val.evalEpoch ) )
	valLogger:close(  )
	collectgarbage(  )
end
function val.evaluateBatch( inputsCpu, labelsCpu )
	-- Initialization.
	local dataTime = val.dataTimer:time(  ).real
	val.netTimer:reset(  )
	--print(#inputsCpu)
	--print(type(inputsCpu))
	if (type(inputsCpu) == 'table') then
		for i = 1, #inputsCpu do
			val.inputs[i]:resize( inputsCpu[i]:size(  ) ):copy( inputsCpu[i] )
			--train.labels[i]:resize( labelsCpu[i]:size(  ) ):copy( labelsCpu[i] )
		end
	else
		val.inputs:resize( inputsCpu:size(  ) ):copy( inputsCpu )
		--train.labels:resize( labelsCpu:size(  ) ):copy( labelsCpu )
	end
	--val.inputs:resize( inputsCpu:size(  ) ):copy( inputsCpu )
	val.labels:resize( labelsCpu:size(  ) ):copy( labelsCpu )
	cutorch.synchronize(  )
	---------------------
	-- FILL IN THE BLANK.
	-- See https://github.com/torch/nn/blob/master/doc/module.md
	-- 1. Feed-forward.
	-- 2. Compute loss and accumulate that to val.lossEpoch.
	-- 3. Compute evaluation metric (e.g. top-1) and accumulate that to train.evalEpoch.
	--    You must call val.evalBatch().
	
	-- 1.
	local output = val.model:forward(val.inputs)
	--print(#val.model.modules[2])
	--[[
	print(#val.model.modules[2].modules[1].modules[1].modules[6].output)--.modules[1].modules[6].output)--[6])--.output)
	print(#val.model.modules[2].modules[1].modules[2].modules[6].output)--.modules[1].modules[6].output)--[6])--.output)
	print(#val.model.modules[2].modules[1].modules[3].modules[6].output)--.modules[1].modules[6].output)--[6])--.output)
	print(#val.model.modules[2].modules[1].modules[3].modules[6].output[1])
	for i = 1, 20 do
		image.save(paths.concat( val.dirRoot, 'figures/' .. i .. '.png' ), val.model.modules[2].modules[1].modules[3].modules[6].output[{1, {i}}])
	end
	assert(1 == 2)
	--]]
	-- 2.
	local err = val.criterion:forward(output, val.labels)
	val.lossEpoch = val.lossEpoch + err

	-- 3.
	local eval = val.evalBatch(output, val.labels)
	val.evalEpoch = val.evalEpoch + eval

	-- END BLANK.
	-------------
	cutorch.synchronize(  )
	val.batchNumber = val.batchNumber + 1
	local netTime = val.netTimer:time(  ).real
	local totalTime = dataTime + netTime
	local speed = val.batchSize / totalTime
	-- Print information.
	val.print( string.format( 'Epoch %d, %d/%d, %dim/s (data %.2fs, net %.2fs), err %.2f, eval %.2f', 
		val.epoch, val.batchNumber, val.epochSize, speed, dataTime, netTime, err, eval ) )
	val.dataTimer:reset(  )
	collectgarbage(  )
end
function val.print( str )
	print( 'VAL) ' .. str )
end
return val
