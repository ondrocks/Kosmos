root = exports ? this

root.planetBufferSize = 100

class root.Planetfield
	constructor: (starfield, planetSize, nearRange, farRange) ->
		@starfield = starfield
		@nearRange = nearRange
		@farRange = farRange
		@planetSize = planetSize
		@starfield = starfield
		@_planetBufferSize = planetBufferSize

		randomStream = new RandomStream(universeSeed)

		# load planet shader
		@shader = xgl.loadProgram("planetfield")
		@shader.uniforms = xgl.getProgramUniforms(@shader, ["modelViewMat", "projMat", "spriteSizeAndViewRanges"])
		@shader.attribs = xgl.getProgramAttribs(@shader, ["aPos", "aColor", "aUV"])

		# we just re-use the index buffer from the starfield because the sprites are indexed the same
		@iBuff = @starfield.iBuff
		if @_planetBufferSize*6 > @iBuff.numItems
			console.log("Warning: planetBufferSize should not be larger than starBufferSize. Setting planetBufferSize = starBufferSize.")
			@_planetBufferSize = @iBuff.numItems

		# prepare vertex buffer
		@buff = new Float32Array(@_planetBufferSize * 4 * 9)
		j = 0
		for i in [0 .. @_planetBufferSize-1]
			randAngle = randomStream.range(0, Math.PI*2)

			for vi in [0..3]
				angle = ((vi - 0.5) / 2.0) * Math.PI #+ randAngle
				u = Math.sin(angle) * Math.sqrt(2) * 0.5
				v = Math.cos(angle) * Math.sqrt(2) * 0.5
				marker = if vi <= 1 then 1 else -1

				@buff[j+3] = 1.0
				@buff[j+4] = 1.0
				@buff[j+5] = 1.0

				@buff[j+6] = u
				@buff[j+7] = v
				@buff[j+8] = marker
				j += 9

		@vBuff = gl.createBuffer()
		@vBuff.itemSize = 9
		@vBuff.numItems = @_planetBufferSize * 4


	setPlanetSprite: (index, position) ->
		if index >= @_planetBufferSize
			console.log("Internal error: Planet index exceeds planet buffer size")
			return

		j = index * 9*4
		for vi in [0..3]
			@buff[j] = position[0]
			@buff[j+1] = position[1]
			@buff[j+2] = position[2]
			#@buff[j+3] = color[0]
			#@buff[j+4] = color[1]
			#@buff[j+5] = color[2]
			j += 9


	render: (camera, gridOffset, blur) ->
		# calculate near planet positions
		numPlanets = 100
		randomStream = new RandomStream(0)
		for i in [0..numPlanets-1]
			@setPlanetSprite(i, [randomStream.range(-10000, 10000), 
								randomStream.range(-10000, 10000), 
								randomStream.range(-10000, 10000)])

		# return if nothing to render
		if numPlanets <= 0 then return

		# push render state
		@_startRender()
		@blur = blur

		# upload planet sprite vertices
		gl.bufferData(gl.ARRAY_BUFFER, @buff, gl.DYNAMIC_DRAW)

		# basic setup
		@vBuff.usedItems = Math.floor(@vBuff.usedItems)
		if @vBuff.usedItems <= 0 then return
		seed = Math.floor(Math.abs(seed))

		# calculate model*view matrix based on block i,j,k position and block scale
		#modelViewMat = mat4.create()
		#mat4.scale(modelViewMat, modelViewMat, vec3.fromValues(@blockScale, @blockScale, @blockScale))
		#mat4.translate(modelViewMat, modelViewMat, vec3.fromValues(i, j, k))
		#mat4.mul(modelViewMat, camera.viewMat, modelViewMat)

		# set shader uniforms
		gl.uniformMatrix4fv(@shader.uniforms.projMat, false, camera.projMat)
		gl.uniformMatrix4fv(@shader.uniforms.modelViewMat, false, camera.viewMat)
		gl.uniform3f(@shader.uniforms.spriteSizeAndViewRanges, @planetSize, @nearRange, @farRange)

		# issue draw operation
		gl.drawElements(gl.TRIANGLES, numPlanets*6, gl.UNSIGNED_SHORT, 0)

		# pop render state
		@_finishRender()


	_startRender: ->
		gl.disable(gl.DEPTH_TEST)
		gl.disable(gl.CULL_FACE)
		gl.depthMask(false)
		gl.enable(gl.BLEND)
		gl.blendFunc(gl.ONE, gl.ONE)

		gl.useProgram(@shader)

		gl.bindBuffer(gl.ARRAY_BUFFER, @vBuff)
		gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, @iBuff)

		gl.enableVertexAttribArray(@shader.attribs.aPos)
		gl.vertexAttribPointer(@shader.attribs.aPos, 3, gl.FLOAT, false, @vBuff.itemSize*4, 0)
		gl.enableVertexAttribArray(@shader.attribs.aColor)
		gl.vertexAttribPointer(@shader.attribs.aColor, 3, gl.FLOAT, false, @vBuff.itemSize*4, 4 *3)
		gl.enableVertexAttribArray(@shader.attribs.aUV)
		gl.vertexAttribPointer(@shader.attribs.aUV, 3, gl.FLOAT, false, @vBuff.itemSize*4, 4 *6)


	_finishRender: ->
		gl.disableVertexAttribArray(@shader.attribs.aPos)
		gl.disableVertexAttribArray(@shader.attribs.aColor)
		gl.disableVertexAttribArray(@shader.attribs.aUV)

		gl.bindBuffer(gl.ARRAY_BUFFER, null)
		gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, null)

		gl.useProgram(null)

		gl.disable(gl.BLEND)
		gl.depthMask(true)
		gl.enable(gl.DEPTH_TEST)
		gl.enable(gl.CULL_FACE)
