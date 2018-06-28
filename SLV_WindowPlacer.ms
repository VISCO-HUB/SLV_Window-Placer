/*  
[INFO] 

NAME = Window Placer
VERSION = 1.1.0
AUTHOR = Vasiliy Lukyanenko
DEV = VISCO
HELP = help\windowPlacer.html

[1.0.0]

* First release =

[1.0.1]
   
- Small bug fixes =

[1.0.2]

* Adopt to new Scripts Launcher =

[1.0.3]

* Added load default windows template feature=

[1.1.0]

* Added: Support for UE (scale window mode)=

[ABOUT]

This script helps to quickly place =
windows in a 3Ds Max scene. =
@=
 Features: =
- Windows list =
- Manual windows placement with a snap =
- Automatic placement = 
- Flip window on local axes (X, Y, Z) =
- "Windows Setup" tool =

[SCRIPT]
*/	
	global _rPlacerRollout
	global _rWindowSettings
	global _rAbout
	global szTemplate = ""

	fn messageWindow m =
	(
		messageBox m title: ("Window Placer")
	)
	
	fn getScriptInfo s releaseInfo: "" =
	(		
		if(releaseInfo != "") do
		(
			r = getINISetting s releaseInfo
			return r
		)
		
		v = getINISetting s "INFO" "VERSION"
		a = getINISetting s "INFO" "AUTHOR"
		n = getINISetting s "INFO" "NAME"
		o = getINISetting s "ABOUT"
		c = getINISetting s "INFO" "DEV"
		h = getINISetting s "INFO" "HELP"
		
		r = for i in (getINISetting s) where i != "ABOUT" and i != "SCRIPT" and i != "COPY" collect i
		
		return #(n, a, v, o, r, c, h)
	)

	fn parseToLine m = 
	(
		if(m.count == 0) do return ""
		
		l = ""				
		for i in m do l += i + "\n"
		return l
	)

	rollout  _rPlacerRollout "Place" 
	(
		listbox lbxList ""  height:15
		checkbutton btnPlace "Place " enabled: true width: 190 height: 40 
		button btnAutoPlace "Create From Border " enabled: true width: 190 height: 40 
		
		group "Mode" (
			radiobuttons rdoPlaceType "" labels: #("Vertex Move", "Scale") default: 2
		)
		
		group "Tip"
		(
			label lblTip "When use \"Place\" mode create window\nfrom top left corner to bottom right\ncorner." align: #left height: 45 offset: [0, 0]
		)	

		group "Mirror"
		(
			button btnFlipX "Flip X" across: 4 offset: [0, 8]
			button btnFlipY "Flip Y" offset: [0, 8]
			button btnFlipXY "Flip XY" offset: [0, 8]
			button btnUnflip "Unflip" offset: [0, 8]
		)
		
		group "Template"
		(
			label lblTip2 "You can load to scene default\ncustomized windows." height: 35 align: #left
			button buttonLoadToScene "Load To Scene"  enabled: false
		)

		global Obj = #()
		global WindowConstraint = #()
		global TapeCount = 0
		
		fn roundTo v t: 100 = (	
			v = v as float
			t = t as float
			v = (ceil (v * t)) as integer
			return  v / t 
		)
		
		fn initPlacer =
		(
			Obj = #()
			lbxList.items = #()
			WindowConstraint = #()
			
			fn getPropArray p o =
			(
				a = #()
				
				try(a = for z in (filterString (getUserProp o p) ", ") collect z as integer) catch(a = "")
				
				return a
			)
			
			fn getPropOffset p o =
			(
				a = 0.0
				try(a = (getUserProp o p) as float) catch()
				return a
			)
				
			for i in geometry where classOf i == Editable_Poly and ((getUserProp i "place_type") == rdoPlaceType.state)  do
			(
				append Obj i

				w = #()
				w[1] = getPropArray "wind_r" i
				w[2] = getPropArray "wind_l" i
				w[3] = getPropArray "wind_t" i
				w[4] = getPropArray "wind_b" i
				w[5] = getPropOffset "wind_w" i
				w[6] = getPropOffset "wind_h" i
				w[7] = getPropArray "wind_f_l" i
				w[8] = getPropArray "wind_f_r" i
							
				append WindowConstraint w
			)
					
			lbxList.items =  for i in Obj collect i.name
		)
		
		
		fn flipObject a =
		(
					
			for s in selection do
			(			
				if(a == -1) do
				(
					if(classOf s.modifiers[1] == Mirror) do deleteModifier s 1
					continue
				)
				
						
				try
				(
					s.modifiers[#Mirror].mirror_axis = a		
				)
				catch
				(
					m = Mirror()
					m.mirror_axis = a 
					addModifier s m
				)
				
				try(update s)catch()
			)
		)
		
		fn autoPlacer =
		(
			undo "Create Windows From Borders" on
			(
				s = selection[1] 
				if(s == undefined) do
				(
					messageWindow "Please select object!"
					return false
				)

				if(subObjectLevel != 3 or classOf s != Editable_Poly or ((polyop.getEdgeSelection s) as array).count < 4) do
				(
					messageWindow "Please select open edges!"
					return false
				)

				-- Select all polys and invert
				f = #{1..s.numFaces}
				polyop.SetFaceSelection s f
				s.capHoles #Edge
				
				
				polyOp.setFaceSelection s -(polyOp.getFaceSelection s)
				
				f = (polyOp.getFaceSelection s) as array
				
				if(f.count == 0) do 
				(
					messageWindow "Please select open edges!"
					return false
				)
				
				
				-- Detach polys for adopt windows
				szName = uniqueName "window_from_borders"
				polyop.detachFaces s f asNode:true name: szName
				
				o = getNodeByName szName exact: true
				
				if(o == undefined) do 
				(
					messageWindow "Select correct open edges!"
					return false
				)
				
				ResetXForm o
				convertToMesh o
				
				v = for f in 1 to o.numFaces where (mod f 2) == 0.0  collect getFace o f
				n = for f in 1 to o.numFaces where (mod f 2) == 0.0 collect (normalize (getFaceNormal o f))
					
				WindowsPoints = #()
				normalDir = #()
					
				-- Find 2 points and normals
				for i in 1 to v.count do 
				(
					print n[i][3]
					if(n[i][3] == 1 or n[i][3] == -1) do continue
					
					z = for ii in 1  to 3 collect getVert o v[i][ii]
					

					p = #()
					p[1] = distance z[1] z[2]
					p[2] = distance z[2] z[3]
					p[3] = distance z[3] z[1]
						
					q = findItem p (amax p)
					
					case q of 
					(
						1: append WindowsPoints #(z[1], z[2])
						2: append WindowsPoints #(z[2], z[3])
						3: append WindowsPoints #(z[3], z[1])
					)
					
					append normalDir n[i]
				)
				
				id = lbxList.selection
				r = WindowConstraint[id][1]
				l = WindowConstraint[id][2]
				t = WindowConstraint[id][3]
				b = WindowConstraint[id][4]
				w = WindowConstraint[id][5]
				h = WindowConstraint[id][6]
				fl = WindowConstraint[id][7]
				fr = WindowConstraint[id][8]
				
				objList = #()
				
				for i in 1 to WindowsPoints.count do
				(	
					if(Obj[id] == undefined) do exit
					
					u = copy Obj[id]
					
					append objList u
					
					v2 = [0,-1,0]--u.transform.row3
							
					p1 = WindowsPoints[i][1]
					p2 = WindowsPoints[i][2]
					
					w0 = abs(p1.z - p2.z)
					w1 = (distance p1 p2) 		
					
					iWidth = (w - sqrt(w1^2 - w0^2)) / 2.0			
					iHeight = (w0 - h) / 2.0
					
														
						try(in coordsys u polyop.moveVert u l [iWidth, 0, 0]) catch()
						try(in coordsys u polyop.moveVert u r [-iWidth, 0, 0]) catch()
						try(in coordsys u polyop.moveVert u t [0, 0, iHeight]) catch()						
						try(in coordsys u polyop.moveVert u b [0, 0, -iHeight]) catch()						
										
						try(if(fl.count > 0) do in coordsys u polyop.moveVert u fl [iWidth / 2.0, 0, 0]) catch()						
						try(if(fr.count > 0) do in coordsys u polyop.moveVert u fr [-iWidth / 2.0, 0, 0]) catch()	
					
					a = acos (dot (normalize normalDir[i]) (normalize v2))
					n = normalize (cross normalDir[i] v2)
					
					q = (quat -a n)	
						
					q = quatToEuler (quat a n)			
					
					q.x = 0
					q.y = 0
					
					rotate u q
						
					if(a == 180.0) do rotate u (eulerAngles 0 0 180.0)
													
					p = p1 - ((p1 - p2) / 2.0)
						
					u.pos = p		
				)
				
				select objList
				try(delete o)catch()
			)
		)
		
		fn placeWindowScale = (
			undo off
			(
				fn tapeCallback o =
				(
					TapeCount += 1
					if(TapeCount > 2) do stopCreating()
				)
					
				n = startObjectCreation Tape returnNewNodes: true newNodeCallback: tapeCallback			
			)
			
			btnPlace.checked = false
			
			undo off
			(
				if(classOf n[2] == Targetobject) then
				(
					btnPlace.checked = true
					
					i = lbxList.selection					
					w = WindowConstraint[i][5]
					h = WindowConstraint[i][6]
					
					---!!!!!
					try(s = instance Obj[i]) 
					catch
					(
						messageWindow "Object not exist!"
						return false
					)
					
					w0 = abs(n[1].pos.z - n[2].pos.z)
					w1 = (distance n[1] n[2]) 
							
					iWidth = (sqrt(w1^2 - w0^2)) as float
					
					iHeight = w0 as float
										
					s.pos = n[1].pos - ((n[1].pos - n[1].target.pos) / 2.0)
										
					sx = ((iWidth - w) / w) + 1.0
					sz = ((iHeight - h) / h) + 1.0
					
					sx = roundTo sx t: 10000
					sz = roundTo sz t: 10000

					scale s [sx, 1, sz]
					
					rotZ = (n[1].transform.rotationpart as EulerAngles).z + 90
					rotate s (EulerAngles 0 0 rotZ)	
										
					try(delete n) catch()										
				)
			)
			
			TapeCount = 0
			try(select s) catch()
			
			if(btnPlace.checked) do placeWindowScale()
		)
		
		fn placeWindow =
		(
			undo off
			(
				fn tapeCallback o =
				(
					TapeCount += 1
					if(TapeCount > 2) do stopCreating()
				)
					
				n = startObjectCreation Tape returnNewNodes: true newNodeCallback: tapeCallback			
			)
			
			btnPlace.checked = false
			
			undo off
			(
				if(classOf n[2] == Targetobject) then
				(
					btnPlace.checked = true
					
					i = lbxList.selection
					r = WindowConstraint[i][1]
					l = WindowConstraint[i][2]
					t = WindowConstraint[i][3]
					b = WindowConstraint[i][4]
					w = WindowConstraint[i][5]
					h = WindowConstraint[i][6]
					fl = WindowConstraint[i][7]
					fr = WindowConstraint[i][8]
					
					try(s = copy Obj[i]) 
					catch
					(
						messageWindow "Object not exist!"
						return false
					)
					
					w0 = abs(n[1].pos.z - n[2].pos.z)
					w1 = (distance n[1] n[2]) 
							
					iWidth = (w - sqrt(w1^2 - w0^2)) / 2.0
					
					iHeight = (w0 - h) / 2.0
										
					s.pos = n[1].pos - ((n[1].pos - n[1].target.pos) / 2.0)
													
					try(in coordsys s polyop.moveVert s l [iWidth, 0, 0]) catch()
					try(in coordsys s polyop.moveVert s r [-iWidth, 0, 0]) catch()
					try(in coordsys s polyop.moveVert s t [0, 0, iHeight]) catch()						
					try(in coordsys s polyop.moveVert s b [0, 0, -iHeight]) catch()						
									
					try(if(fl.count > 0) do in coordsys s polyop.moveVert s fl [iWidth / 2.0, 0, 0]) catch()						
					try(if(fr.count > 0) do in coordsys s polyop.moveVert s fr [-iWidth / 2.0, 0, 0]) catch()						
						
					rotZ = (n[1].transform.rotationpart as EulerAngles).z + 90
					rotate s (EulerAngles 0 0 rotZ)	
										
					try(delete n) catch()										
				)
			)
			
			TapeCount = 0
			try(select s) catch()
			
			if(btnPlace.checked) do placeWindow()
		)
			
		on rdoPlaceType changed v do (
			initPlacer()
			
			btnAutoPlace.enabled = v != 2
		)
		
		on _rPlacerRollout open do
		(		
			initPlacer()
					
			szTemplate = (getFilenamePath (getThisScriptFilename())) + "help\\windowPlacer\\windowPlacerTemplate.max"			
			if(doesFileExist szTemplate) do buttonLoadToScene.enabled = true
		)	
		
		
		on buttonLoadToScene pressed do
		(
			if(queryBox "Merge default windows to scene?" title: "Template" and doesFileExist szTemplate) do
			(
				disableSceneRedraw()
				mergeMAXFile szTemplate #select #promptDups #renameMtlDups quiet: true
				toolMode.selectioncenter() 
				enableSceneRedraw()
				max tool zoomextents all
				initPlacer()
			)
		)
			
		on btnPlace changed x do
		(	
			initPlacer()
			
			i = lbxList.selection
			
			stopCreating()
			
			if(x != true or i == 0) do (
				btnPlace.checked = false
				return false
			)
			
			case rdoPlaceType.state of (
				1: (				
					wr = WindowConstraint[i][1]
					wl = WindowConstraint[i][2]
						
					if(wr != "" and wl != "") do placeWindow()								
				)
				2: (
					ww = WindowConstraint[i][5]
					wh = WindowConstraint[i][6]
					
					if(ww != "" and wh != "") do placeWindowScale()	
				)
			)
		)
		
		on btnAutoPlace pressed do
		(
			initPlacer()
			
			i = lbxList.selection
			
			if(i > 0) do autoPlacer()
		)
		
		on btnFlipX pressed do flipObject 0
		on btnFlipY pressed do flipObject 1
		on btnFlipXY pressed do flipObject 3
		on btnUnflip pressed do flipObject -1
	)

	rollout _rWindowSettings "Window Setup" 
	(
		group "Setup Window Type" (
			radiobuttons rdoPlaceType "" labels: #("Vertex Move", "Scale") default: 2
		)
		
		group "STEP 1:Transform"
		(
			button btnResetXForm "Reset XForm"
			button btnSetPivot "Set Pivot Point"
		)
		
		group "STEP 2: Size Setup"
		(
			button btnAddDim "Set Size"		
		)
		
		group "STEP 3: Vertex Sets"
		(
			button btnAddLeftVert "Add Left Vertexes"
			button btnAddRightVert "Add Right Vertexes"		
			button btnAddTopVert "Add Top Vertexes"
			button btnAddBottomVert "Add Bottom Vertexes"		
		)
		
		group "STEP4: Floating Elements (Optional)"
		(
			button btnAddLeftFloat "Add Left Vertexes"	
			button btnAddRightFloat "Add Right Vertexes"					
		)
		
		group "Tip"
		(
			label lblTip "Don't forget: Build tape always from\ntop left corner and finish\nin right bottom corner!" align: #left height: 70 offset: [0, 0]
		)	
		
		fn toggleInterface = (			
			v = rdoPlaceType.state
			btnResetXForm.enabled = true
			btnSetPivot.enabled = true
			btnAddDim.enabled = true
			btnAddLeftVert.enabled = v != 2
			btnAddRightVert.enabled = v != 2
			btnAddTopVert.enabled = v != 2
			btnAddBottomVert.enabled = v != 2
			btnAddLeftFloat.enabled = v != 2
			btnAddRightFloat.enabled = v != 2			
		)
		
		fn doResetXForm =
		(
			s = selection[1] 
			if(s == undefined) do
			(
				messageWindow "Please select object"
				return false
			)
			
			ResetXForm s
			convertToPoly s			
		)
		
		fn setTransform =
		(
			s = selection[1] 
			if(s == undefined) do
			(
				messageWindow "Please select object"
				return false
			)
						
			try
			(			
				undo off
				(
					fn tapeCallback o =
					(
						TapeCount += 1
						if(TapeCount > 2) do stopCreating()
					)
						
					t = startObjectCreation Tape returnNewNodes: true newNodeCallback: tapeCallback			
					
					if(classOf t[2] == Targetobject) do 
					(	
						d = (t[2].pos - t[1].pos) / 2
						p = t[1].pos + d
				
						s.pivot = p
										
						try(delete t) catch()
						select s
						TapeCount = 0
						setUserProp s "place_type" rdoPlaceType.state
						messageWindow ("Center setup: X: " + abs(d[1]) as string + " Y: " + abs(d[3]) as string)
					)
				)
				
			)
			catch
			()
			
			_rPlacerRollout.initPlacer()			
			
			ResetXForm s
			convertToPoly s
			
			_rPlacerRollout.initPlacer()
		)
		
		fn setUserPropVert n =
		(
			try
			(			
				a = ($.EditablePoly.GetSelection #Vertex) as array
				z = ""
				for i in a do z += i as string + ","
				setUserProp $ n (z as string)		
				setUserProp $ "place_type" rdoPlaceType.state
				messageWindow ("Added " + a.count as string + " points!")									
			)
			catch
			(
				messageWindow "Error!!"
			)
			
			_rPlacerRollout.initPlacer()
		)
		
		fn setUserPropOffset =
		(
			s = selection[1] 
			if(s == undefined) do
			(
				messageWindow "Please select object"
				return false
			)
			
			try
			(			
				undo off
				(
					fn tapeCallback o =
					(
						TapeCount += 1
						if(TapeCount > 2) do stopCreating()
					)
						
					t = startObjectCreation Tape returnNewNodes: true newNodeCallback: tapeCallback			
					
					if(classOf t[2] == Targetobject) do 
					(	
						w0 = abs(t[1].pos.z - t[2].pos.z)
						w1 = (distance t[1] t[2]) 
							
						iWidth = sqrt(w1^2 - w0^2)
						iHeight = w0
						
					
						setUserProp s "wind_h" iHeight
						setUserProp s "wind_w" iWidth
						
						setUserProp s "place_type" rdoPlaceType.state
										
						try(delete t) catch()
						select s
						TapeCount = 0
						
						messageWindow ("Width: " + iWidth as string + " Height: " + iHeight as string) 
					)
				)					
			)
			catch
			()
			
			_rPlacerRollout.initPlacer()
		)
		
		on _rWindowSettings open do (
			toggleInterface()
		)
		
		on btnResetXForm pressed do doResetXForm()
		on btnAddRightVert pressed do setUserPropVert "wind_r"
		on btnAddLeftVert pressed do setUserPropVert "wind_l"
		on btnAddBottomVert pressed do setUserPropVert "wind_b"
		on btnAddTopVert pressed do setUserPropVert "wind_t"
		
		on btnAddDim pressed do setUserPropOffset()		

		on btnAddRightFloat pressed do setUserPropVert "wind_f_r"
		on btnAddLeftFloat pressed do setUserPropVert "wind_f_l"	
			
		on btnSetPivot pressed do setTransform()
		
		on rdoPlaceType changed v do (
			toggleInterface()			
		)
	)


	rollout _rAbout "About" 
	(
		label lblName "" 
		label lblVer "" 
		
		label lblAuthor "" height: 30
		label lblCopy ""  height: 30
		button btnHelp "Help" enabled: false
		
		fn getHelp run: false =
		(
			s = getThisScriptFilename()
			i = getScriptInfo s
			szHelp = (getFilenamePath s) + i[7]
			if(doesFileExist szHelp) do btnHelp.enabled = true
				
			if(run) do ShellLaunch szHelp ""
		)
		
		on btnHelp pressed do getHelp run: true
			
		on _rAbout open do
		(		
			i = getScriptInfo (getThisScriptFilename())
				
			lblName.caption = i[1]
			lblAuthor.caption = i[2]
			lblVer.caption = i[3]
			lblCopy.caption = i[6]
			
			getHelp()
		)
	)

	try(closeRolloutFloater rWindowPlacer) catch()
	global rWindowPlacer = newRolloutFloater "Window Placer" 230 800

	addRollout _rPlacerRollout rWindowPlacer rolledUp:false 
	addRollout _rWindowSettings rWindowPlacer rolledUp:true 
	addRollout _rAbout rWindowPlacer rolledUp:true 