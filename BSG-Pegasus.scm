;; THIS FILE IS FOR THE PEGASUS VERSION ONLY...BASE GAME SCRIPT IS DIFFERENT
; THIS FILE IS FOR THE PEGASUS VERSION ONLY...BASE GAME SCRIPT IS DIFFERENT

;gimp invokation:
;gimp-2.g -b "(script-fu-BSGP-Run-Batch \"C:\\Documents and Settings\\Aaron Walker\\Desktop\\BSG PBEM Games\\sandbox\\TestData.csv\")" -b "(gimp-quit 0)"

; globals..they're ugly, but they save us from other constraints and from passing mylayers to every function
(define mylayers nil)
(define asgncnt nil)
(define civcnt nil)
(define specialcnt nil)
(define basestarfirst nil)
(define cardoffsetY nil)
(define playercount nil)
(define imgscale 0.75)	;use this to scale images on the cylon fleet board
(define image nil)
(define outlineoption FALSE)

(define (script-fu-BSGP-Run-Batch FileName)
	(while (= 32 (char->integer (string-ref FileName 0)))
		(set! FileName (substring FileName 1))
	)
	(script-fu-BSGP-Run 0 FileName)
)

(script-fu-register "script-fu-BSGP-Run-Batch"
	""
	"BSG Pegasus Run in Batch Mode"
	"APW"
	"APW"
	"Now"
	"RGB*"
	SF-VALUE "Data File Name" ""
)


(script-fu-register "script-fu-BSGP-Run"
	"<Image>/BSGP-Run"
	"BSG Import"
	"APW"
	"APW"
	"Now"
	"RGB*"
	SF-TOGGLE "Show Image Upon Completion?" TRUE
	SF-FILENAME "Data File" ""
)

(define (script-fu-BSGP-Run showimage FileName)
(let* 	
	(
		(datafile nil)
		(data nil)
		(myvalues nil)
		(setname nil)
		(gamename nil)
		(gameturn nil)
		(nexttok "")
		(filepath nil)
		(fname nil)
		(fname2 nil)
;		(image nil)
		(drawable nil)
		(jpgimage 0)
		(showships 0)
		(objflag nil)
		(usePeg FALSE)
		(useExo FALSE)
		(useDB FALSE)
		(useRev FALSE)
		(useCF FALSE)
		(useCCW FALSE)
	)
	(set! asgncnt (make-vector 8 0))
	(set! civcnt (make-vector 6 0))
	(set! specialcnt 0)
	(set! basestarfirst 0)
	(set! logfname "bsgp-Run.log")
	(set! objflag "New Caprica")
	
	(set! filepath (car (splitfullfname FileName)))
	(if (string=? (caddr (splitfullfname FileName)) "csv")
		(begin
			(set! datafile (open-input-file FileName))
			(set! nexttok (read datafile))	; this should be "Game"
		)
		(begin
			(initlog filepath) ;do this to make sure there is a valid log file open
			(logit "Invalid file type, must be .csv")
		)
	)
	(if (string=? nexttok "Game")
		(begin
		(set! data (getcsvline datafile))
		(set! setname nexttok)
		(set! myvalues (car data))
		(set! nexttok (cadr data))

		; Game-specific data
		(set! gamename (car myvalues))
		(set! gameturn (cadr myvalues))

		; Expansions
		(set! myvalues (cddr myvalues))
		(set! usePeg (string=? (car myvalues) "Pegasus"))			; Need to know whether to show Pegasus/Overlay/Treachery
		(set! useExo (string=? (cadr myvalues) "Exodus"))			; Need a graveyard for executions, and the Loyalty cards.
		(set! useDB (string=? (caddr myvalues) "Daybreak"))			; Colonial One overlay, Mutiny Deck
		(set! useRev (string=? (cadddr myvalues) "Revelations"))	; Faith deck

		; Modules
		(set! myvalues (cddddr myvalues))
		(set! objflag (car myvalues))
		(set! useCF (string=? (cadr myvalues) "Cylon Fleet"))
		;(set! useCCW (
		
		; We can't put the 'log' token at the top of the list.
		(when (and (not (null? (cddr myvalues))) (string-ci=? (caddr myvalues) "Log")) (initlog filepath))
		
		(p_getlayerpos "ALL")	;debugging only
		(logit (string-append gamename " ---- Turn " gameturn))
		
		(set! fname (string-append filepath (bsgp-make-fname gamename "MASTER.xcf")))
	
		(set! image (car (gimp-file-load 1 fname fname)))
		(set! drawable (car (gimp-image-get-active-drawable image)))
		(set! mylayers (cadr (gimp-image-get-layers image)))
		
		(set! cardoffsetY (bsgp-ConfigureBoard image objflag usePeg useExo useCF useDB useRev) )
		
		(gimp-text-layer-set-text (vector-ref mylayers (p_getlayerpos "Turn")) (string-append "Turn " gameturn))
		
		; Giant while loop to read in lines, then process them.
		(while (not (eof-object? nexttok)) 
			(set! data (getcsvline datafile))
			(set! setname nexttok)
			(set! myvalues (car data))
(logit setname)
(logit myvalues)
			(set! nexttok (cadr data))
			(case (string->symbol setname)
				((Characters) (bsgp-Characters image myvalues) (set! mylayers (cadr (gimp-image-get-layers image))))
				((EliminatedCharacters) (bsgp-EliminatedCharacters myvalues))
				((Reserves) 
					(when (= (length myvalues) 4)
						(bsgp-DeadVipers (car (reverse myvalues)))
						(set! myvalues (reverse (cdr (reverse myvalues))))
					) ;when
					(bsgp-Counters myvalues (p_getlayerpos "Reserves"))
				)
				((Resources) (bsgp-Counters myvalues (p_getlayerpos "FuelCntr"))) 
				((ResourceDamage) (bsgp-ResourceDamage myvalues))
				((Decks) (bsgp-Counters myvalues (p_getlayerpos "Destiny"))) 
				((SkillDecks) (bsgp-Counters myvalues (p_getlayerpos "PoliticsCntr"))) 
				((PlayerCards) (bsgp-Counters myvalues (p_getlayerpos "PlayerCardCntr"))) 
				((CivShips) (bsgp-Counters myvalues (p_getlayerpos "CivCntr")))
				((DamagedCivilians) (bsgp-DamagedCivilians myvalues (p_getlayerpos "DamagedCivs")))
				((DestroyedBasestar) (bsgp-DestroyedBasestar myvalues (p_getlayerpos "DestroyedBasestar")))
				((Roles) (bsgp-Roles  myvalues))
				((PlayerLocations) (bsgp-Players  myvalues useDB))
				((JumpTrack) (bsgp-JumpTrack myvalues))
				((BoardingParty) (bsgp-BoardingParty myvalues 1))
				((OccForce) (bsgp-BoardingParty myvalues 0))
				((Distance) (bsgp-Distance  myvalues))
				((GamePhase) (bsgp-Phase myvalues useCF))
				((OPG) (bsgp-1PG  myvalues))
				((Damage) (bsgp-Damage  myvalues))
				((BoardSpecial) (bsgp-BoardSpecial  myvalues))
				((Assignments) (bsgp-Assignments  myvalues))
				((Graveyard) (bsgp-Graveyard image myvalues))
				((Cylons) (bsgp-Cylons  myvalues))
				((Sector) (bsgp-Sector myvalues TRUE showships))
				((CylonFleet) (bsgp-Sector myvalues FALSE showships))
				((Scar) (bsgp-ShipsHRV (car myvalues) 4 1 showships))
				((Basestar) (bsgp-Basestar myvalues))
				((Civilians) (bsgp-ShipsCivilians (car myvalues) (cdr myvalues)))
				((Objective) (bsgp-Objective myvalues))
				((Allies) (bsgp-Allies myvalues useDB))
				((Trauma) (bsgp-TrLoy myvalues "Trauma"))
				((LoyaltyCards) (bsgp-TrLoy myvalues "LoyaltyCards"))
				((Mutiny) (bsgp-TrLoy myvalues "Mutiny"))
				((BGColor) (bsgp-BGColor myvalues))
				((SearchForHome) (bsgp-SearchForHome myvalues))
				((Option) 
					(case (string->symbol (car myvalues))
						((ShowShips) (set! showships 1))
						((View) (set! showimage 1))
						((JPG) (set! jpgimage 1))
						((OutlineCounters) (set! outlineoption TRUE))
					)
				)
			) ;case
		) ;while

		(set! fname (string-append filepath (bsgp-make-fname gamename gameturn) ".xcf"))
; we need to reset drawable because if there was outlinging (with creation & destruction of layers), it may no longer be valid
		(set! drawable (car (gimp-image-get-active-drawable image)))

		(logit (gimp-file-save 0 image drawable fname fname))

		(when (= jpgimage 1) 
			(gimp-image-flatten image)
			(set! drawable (car (gimp-image-get-active-drawable image)))
			(set! fname2 (string-append filepath (bsgp-make-fname gamename gameturn) ".jpg"))
			(logit (file-jpeg-save 1 image drawable fname2 fname2 0.5 0 1 0 "Generated by bsgp-Run" 0 1 0 0))
		)

		(when (= showimage 1)
			(gimp-image-delete image)

			(set! image (car (gimp-file-load 1 fname fname)))
			(set! drawable (car (gimp-image-get-active-drawable image)))
			(gimp-display-new image)
			(gimp-image-clean-all image)
		)
		) ;if
		(begin
			(initlog filepath) ;do this to make sure there is a valid log file open
			(logit "Invalid data, no Game record found.")
		)

	) ;when
	(logit "End")
	(when (port? datafile) (close-input-port datafile))
	(initlog "")
) ;let*
) ;define



(define (bsgp-make-fname gamename turnname)
	(string-append "BSGP " gamename " - " turnname))

(define (btoint boolres)
	; this takes a boolean (#t or #f) and turns it into the GIMP integer equivalent
	(if (eq? #t boolres) TRUE FALSE))
	
(define (MoveTokenToPlayer layerpos playerid)
	(gimp-drawable-set-visible (vector-ref mylayers layerpos) TRUE)
	(gimp-layer-translate (vector-ref mylayers layerpos) 0 (* cardoffsetY (-- playerid)))
)


(define (p_getused posname)
(let*
	(
		(mycnt 0)
		(mypos nil)
	)
	(set! mypos (p_getlayerpos posname))
	(while (= (car (gimp-drawable-get-visible (vector-ref mylayers mypos))) TRUE)
		(set! mypos (++ mypos))
		(set! mycnt (++ mycnt))
	)
	mycnt
) ;let
) ;define
		
		
;
(define (p_getlayerpos layername)
(let*
	(
		(offsets #(0 6 1 6 4 
				1 3 1 7 7 
				7 1 7 7 7 7 4 2 8 2 8 
				5 4 9 
				10 38 12 12 12 1 11 9
				2 5 30 6 1 
				7 6 7 4 4 
				12 14 6 6 32 6 
				10 2 7 7 7 7
				1 9 38 3 35
				1 9 1 2 2 1 1 1 1 5
				2 1 1 1 1 1 1 3)
		)
		(names #("Filter" "Turn" "Reserves" "FuelCntr" "Distance" 
			"CivCntr" "Destiny" "CrisisCntr" "PoliticsCntr" "PlayerCardCntr"	
			"QuorumCntr" "LoyaltyCntr" "TraumaCntr" "MutinyCntr" "Eliminated" "FuelDial" "ResourceDamage" "DamagedCivs" "DestroyedBasestar" "DeadViper" "JumpTrack" 
			"PursuitTrack" "Current" "DamageToken" 
			"PlayerToken" "Pilot" "PilotMkVII" "PilotAR" "Scar" "Special" "CurrentMission" "CurrentMissionStatus"
			"FinalDest" "JumpDistance" "ReserveToken" "CivToken" "Cylon" 
			"SuperCrisis" "Assign" "OccForce" "Centurion" "Civilian" 
			"Viper" "ViperMkVII" "AssaultRaptor" "Raider" "HeavyRaider" "BasestarDmg" 
			"Basestar" "SkillCard" "LoyaltyCard" "Trauma" "Mutiny" "Stranded" 
			"1PG" "PlayerCard" "BlankCard5" "Allies" "NCCivToken" 
			"CrisisToken" "HubDestroyed" "RebelBasestarToken" "CylonLocations" "CylonFleet" "NewCaprica" "Demetrius" "RebelBasestar" "PoliticsDeck" "TreacheryDeck" 
			"PegasusDestroyed" "ColonialOneDestroyed" "ColonialOneDaybreak" "Pegasus" "Graveyard" "Logo" "Borders" "MainBoard")
		)
		(fnd nil)
		(cnt 0)
		(totaloffset 0)
	)
	(while (< cnt (vector-length offsets))
		(set! totaloffset (+ totaloffset (vector-ref offsets cnt)))

		(when (string=? layername "ALL")
			(logit (string-append (number->string cnt) ": " (vector-ref names cnt) "(" (number->string totaloffset) ")")); (" (number->string (vector-ref offsets (+ cnt 1) )) ")"))
		)

		(when (string=? layername (vector-ref names cnt))
			(set! fnd totaloffset)
			(set! cnt (vector-length offsets))
		) 
		(set! cnt (++ cnt))
	) 
	(when (and (null? fnd) (not (string=? layername "ALL"))) (logit (string-append "ERROR - Could not find Layer: " layername)))
	fnd
) 
) ;p_getlayerpos
;
(define (bsgp-ResourceDamage myvalues)
(let*
	(
		(layerpos (p_getlayerpos "ResourceDamage"))
	)
	(when (= (car myvalues) 1) (gimp-drawable-set-visible (vector-ref mylayers layerpos) TRUE))
	(when (= (cadr myvalues) 1) (gimp-drawable-set-visible (vector-ref mylayers (+ layerpos 1)) TRUE))
)
)

(define (bsgp-Counters myvalues layerpos)
(let* 
	(
		(fmt (vector -1 -1 -1 -1 -1 -1 -1 ; Filters, turn
				2 2 2 2 2 2		; Reserves
				1 1 1 1 		; Resources
				0 3 3 3 0 		; Distance, Civilians, Destiny 
				3 3 3 3 3 3 3 	; Crises, Quorum, Supers, Mutiny 
				0 0 0 0 0 0 0	; Skills
				0 0 0 0 0 0 0 0	; Hands, Quorum
				0 0 0 0 0 0 0	; loyalty counts
				0 0 0 0 0 0 0	; trauma counts
				0 0 0 0 0 0 0)	; mutiny counts	
				)
			;fmt values: 0=number only, 1=number + Dial, 2 = x##, 3=x ##
		(dial (vector 8 8 10 12))
		(dial_id nil)
		(dial_layerid nil)
		(dial_rot nil)
		(rot1 (* 22.5 0.0175))	;22.5 degrees in radians
	)
	(while (and (not (null? myvalues)) (number? (car myvalues)))
		(case (vector-ref fmt layerpos)
			((0) (gimp-text-layer-set-text (vector-ref mylayers layerpos) (number->string (car myvalues))))
			((1) 
				(gimp-text-layer-set-text (vector-ref mylayers layerpos) (number->string (car myvalues)))
				(set! dial_id (- layerpos (p_getlayerpos "FuelCntr")))
				(set! dial_layerid (vector-ref mylayers (+ (p_getlayerpos "FuelDial") dial_id)))
				(set! dial_rot (* (- (car myvalues) (vector-ref dial dial_id)) rot1))
				(gimp-drawable-transform-rotate-default dial_layerid dial_rot TRUE 0 0 TRUE TRANSFORM-RESIZE-ADJUST)
			)
			((2) (gimp-text-layer-set-text (vector-ref mylayers layerpos) (string-append (if (> 10 (car myvalues)) "x " "x") (number->string (car myvalues)))))
			((3) (gimp-text-layer-set-text (vector-ref mylayers layerpos) (string-append (if (> 100 (car myvalues)) "x " "x") (number->string (car myvalues)))))
		) ;case

		(when (and (= outlineoption TRUE) (not (= layerpos (p_getlayerpos "Distance")) ))	;we don't do an outline for distance, it's black already
			(outlineText (vector-ref mylayers layerpos) 6 '(0 0 0))
			(set! mylayers (cadr (gimp-image-get-layers image)))

		)
		(set! myvalues (cdr myvalues)) 
		(set! layerpos (++ layerpos)) 
	) ;while
) ;let
) ;define

(define (bsgp-DeadVipers vipercnt)
(let*
	(
		(deadpos (p_getlayerpos "DeadViper"))
	)
	(while (> vipercnt 0)
		(gimp-drawable-set-visible (vector-ref mylayers deadpos) TRUE)
		(set! deadpos (++ deadpos))
		(set! vipercnt (-- vipercnt))
	) ;while
) ;let
) ;define


(define (bsgp-JumpTrack myvalues)
(let*
	(
		(JumpLayerpos (p_getlayerpos "JumpTrack"))
		(curjump JumpLayerpos)
		(jumpstate nil)
	)
	(set! jumpstate (car myvalues))
	(while (< curjump (+ JumpLayerpos 5))
		(when (= curjump (+ jumpstate JumpLayerpos)) 
			(gimp-drawable-set-visible (vector-ref mylayers curjump) TRUE)
			(set! curjump (+ JumpLayerpos 5))
		)
		(set! curjump (++ curjump))
	) ;while
	(when (= (length myvalues) 2) ;we have a pursuittrack value
		(set! jumpstate (cadr myvalues))
		(set! JumpLayerpos (p_getlayerpos "PursuitTrack"))
		(set! curjump JumpLayerpos)
		(while (< curjump (+ JumpLayerpos 4))
			(when (= curjump (+ jumpstate JumpLayerpos)) 
				(gimp-drawable-set-visible (vector-ref mylayers curjump) TRUE)
				(set! curjump (+ JumpLayerpos 4))
			)
			(set! curjump (++ curjump))
		) ;while
	) ;when
); let
);define


(define (bsgp-BoardingParty myvalues whichtype)
; this is used for both the centurions on Galactica and the occupation forces on New Caprica
; whichtype: 1=centurions, 2=occupation forces
(let*
	(
		(curCentpos nil)
		(offsetX nil)
		(offsetY nil)
		(curloc nil)
		(curcnt nil)
		(totalcent 0)
		(centoffx nil)
		(centoffy nil)
	)
	(set! curloc myvalues)
	(while (not (null? curloc))
		(set! totalcent (+ totalcent (car curloc)))
		(set! curloc (cdr curloc))
	)
	(if (= whichtype 1)
		(begin
			(set! curCentpos (+ (p_getlayerpos "Centurion") (-- totalcent)))
			(set! centoffx 49)
			(set! centoffy 20)
		)
		(begin
			(set! curCentpos (+ (p_getlayerpos "OccForce") (-- totalcent)))
			(set! centoffx 150)
			(set! centoffy -20)
		)
	) ;if
	(set! curloc 0)
	(while (not (null? myvalues))
		(when (< 0 (car myvalues))
			(set! curcnt (car myvalues))
			(while (> curcnt 0)
				(gimp-layer-set-visible (vector-ref mylayers curCentpos) TRUE)
				(set! offsetX (* curloc centoffx))
				(set! offsetY (* (-- curcnt) centoffy))
				(gimp-layer-translate (vector-ref mylayers curCentpos) offsetX offsetY)
				(set! curCentpos (-- curCentpos))
				(set! curcnt (-- curcnt))
			)
		) ;when
		(set! curloc (++ curloc))
		(set! myvalues (cdr myvalues))
	) ;while
) ;let
) ;define


(define (bsgp-EliminatedCharacters myvalues)
(let*
	(
		(c_elimpos (p_getlayerpos "Eliminated"))
		(playerid 0)
	)
	(while (not (null? myvalues))
		(set! playerid (- (car myvalues) 1))
		(logit playerid)
		(gimp-layer-set-visible (vector-ref mylayers (+ c_elimpos playerid)) TRUE)
		(gimp-layer-translate (vector-ref mylayers (+ c_elimpos playerid)) 0 (* cardoffsetY playerid))
		(set! myvalues (cdr myvalues))
	)
) ; let
) ; define

(define (bsgp-Characters image myvalues)
;bsgp-Characters is for the initial setup.
(let*
	(
		(c_playerpos (p_getlayerpos "PlayerCard"))
		(c_tokenpos (p_getlayerpos "PlayerToken"))
		(playerid 0)
		(curoffset 0)
		(playerpos nil)
		(tokenpos nil)
		(playername nil)
		(playercnt nil)
		(cntr nil)
		(plyroffset nil)
	)
	(set! playercount (length myvalues)) ;this is a global that is used by other functions
	(set! playercnt (length myvalues))
	(while (< playercnt 7) 
		(gimp-drawable-set-visible (vector-ref mylayers (+ (p_getlayerpos "BlankCard5") (- playercnt 4))) TRUE)
		(gimp-drawable-set-visible (vector-ref mylayers (+ (p_getlayerpos "PlayerCardCntr") playercnt)) FALSE)
		(gimp-drawable-set-visible (vector-ref mylayers (+ (p_getlayerpos "SkillCard") playercnt)) FALSE)
		(set! playercnt (++ playercnt))
	)
	(while (not (null? myvalues))
		; get the name of the current player
		; walk the cards until it's found
		; put the card in the correct place and make it visible
		; find the token for the player and move it into the correct order
		(set! playerpos (+ c_playerpos playerid))
		(set! tokenpos (+ c_tokenpos playerid))
		(set! playername (car myvalues))
		(set! plyroffset -1)
		(set! cntr 0)
		(while (< cntr 38)
			(when (string=5? playername (car (gimp-drawable-get-name (vector-ref mylayers (+ playerpos cntr)))))
				(set! plyroffset cntr)
				(set! cntr 38)
			) ;when
			(set! cntr (++ cntr))
		) ;while
		(when (= plyroffset -1) (logit (string-append "ERROR - Could not find character: " playername)))
		
		; so now I know where the card and token are relative to the current
		; we need to make card visible and move it to the right place
		; the token will be made visible by bsgp-players when it is put in a location
		(MoveTokenToPlayer (+ playerpos plyroffset) (++ playerid))

		; now we need to reorganize the layers
		;the layers need to be moved up playeroffset times, I believe...
		(set! cntr plyroffset)
		(while (> cntr 0)
			(gimp-image-raise-layer image (vector-ref mylayers (+ playerpos plyroffset)))
			(gimp-image-raise-layer image (vector-ref mylayers (+ tokenpos plyroffset)))
			(set! cntr (-- cntr))
		) ;while
		;the layers are no longer in the same order as mylayers, so refresh it
		(set! mylayers (cadr (gimp-image-get-layers image)))
		(set! myvalues (cdr myvalues))
		(set! playerid (++ playerid))
	) ;while
	
) ;let
) ;define



(define (bsgp-Roles myvalues)
; roles myvalues is of the form (CurrentPlayerID PresidentID QuorumCnt AdmiralID NukeCnt [CAGID] [MutID])
; note that the id's are all 1-based, to match the source file
(let*
	(
		(c_tokenpos (p_getlayerpos "Current"))
		(c_qcardtxt (p_getlayerpos "QuorumCntr"))
	)
	
	; Current Player
	(MoveTokenToPlayer c_tokenpos (car myvalues))
	(set! myvalues (cdr myvalues))	; Pop off the Current Player - top is now PresidentID
	
	; President - Seal, Quorum card back, count
	(MoveTokenToPlayer (+ c_tokenpos 1) (car myvalues))	; President Seal
	(MoveTokenToPlayer (+ c_tokenpos 2) (car myvalues))	; Quorum Cards
	(MoveTokenToPlayer c_qcardtxt (car myvalues))		; Quorum Cards counter

	; Quorum card count text
	(bsgp-Counters (list (cadr myvalues)) c_qcardtxt)
	(set! myvalues (cddr myvalues))	; Pop off the President and Quorum count - top is now AdmiralID

	; Admiral - Insignia, nukes
	(MoveTokenToPlayer (+ c_tokenpos 3) (car myvalues))	; Admiral Seal
	(when (> (cadr myvalues) 0) (MoveTokenToPlayer (+ c_tokenpos 4) (car myvalues)) )	; Nuke 1
	(when (> (cadr myvalues) 1)	(MoveTokenToPlayer (+ c_tokenpos 5) (car myvalues)) )	; Nuke 2
	(when (> (cadr myvalues) 2)	(MoveTokenToPlayer (+ c_tokenpos 6) (car myvalues)) )	; Nuke 3
	
	(set! myvalues (cddr myvalues))	; Pop off the Admiral and Nukes - top is now CAGID
	
	; CAG insignia
	(when (> (car myvalues) 0) (MoveTokenToPlayer (+ c_tokenpos 7) (car myvalues)) )

	; Mutineer
	(when (> (cadr myvalues) 0) (MoveTokenToPlayer (+ c_tokenpos 8) (cadr myvalues)))
) ;let
) ;define


;
(define (bsgp-TrLoy myvalues tokentype)
; display of trauma token counts and loyalty card counts are identical and are only show by request.
(let*
	(
		(cntr 0)
		(tokenpos nil)
		(cntrpos nil)
	)
	; we need to show the tokens and counters
	(if (string=? tokentype "Trauma")
		(begin
			(set! tokenpos (p_getlayerpos "Trauma"))
			(set! cntrpos (p_getlayerpos "TraumaCntr"))
		)
		(if (string=? tokentype "Mutiny")
			(begin
				(set! tokenpos (p_getlayerpos "Mutiny"))
				(set! cntrpos (p_getlayerpos "MutinyCntr"))
			)
			(begin
				(set! tokenpos (p_getlayerpos "LoyaltyCard"))
				(set! cntrpos (p_getlayerpos "LoyaltyCntr"))
			)
		)
	) ; if
	(while (< cntr playercount)
		(when (or (> (car myvalues) 0) (string=? tokentype "Trauma"))
			(gimp-drawable-set-visible (vector-ref mylayers (+ tokenpos cntr)) TRUE)
			(when (or (> (car myvalues) 0) (string=? tokentype "Trauma"))
				(gimp-drawable-set-visible (vector-ref mylayers (+ cntrpos cntr)) TRUE)
				(gimp-text-layer-set-text (vector-ref mylayers (+ cntrpos cntr)) (number->string (car myvalues)) )

				(when (= outlineoption TRUE)	
					(outlineText (vector-ref mylayers (+ cntrpos cntr)) 6 '(0 0 0))
					(set! mylayers (cadr (gimp-image-get-layers image)))
				)
			)
		)
		(set! myvalues (cdr myvalues))
		(set! cntr (++ cntr))
	); while
);let
) ;bsgp-TrLoy


(define (bsgp-1PG myvalues)
; flag once-per-game abalities as having been used.
(let*
	(
		(c_1pgpos (p_getlayerpos "1PG"))		;position in the layer vector of the first 1PG image
		(cntr 0)
	)
	(while (not (null? myvalues))
		(case (car myvalues)
			((0) (gimp-drawable-set-visible (vector-ref mylayers (+ c_1pgpos cntr)) TRUE))
			((2) (MoveTokenToPlayer (+ c_1pgpos 7) (+ cntr 1))) 
			((3) (MoveTokenToPlayer (+ c_1pgpos 8) (+ cntr 1)))
		)
		(set! myvalues (cdr myvalues))
		(set! cntr (++ cntr))
	) ;while
) ;let
) ;define



(define (bsgp-Cylons myvalues)
;Format: "Cylons",<playerid>,<CylonType>,<SuperCrisis Count>,<InfMode> [,<playerid>,<CylonType>,<SuperCrisis Count>,<InfMode> [,...]]
;CylonType Valid Values:
;"C" = Revealed Cylon
;"LS" = Cylon Leader w/Sympathetic Agenda
;"LH" = Cylon Leader w/Hostile Agenda
;"L" = Cylon Leader w/Motives
;"S" = Sympathetic Cylon
;<InfMode>= 1 for Infiltrator, otherwise 0

(let*
	(
		(c_cylonpos (p_getlayerpos "Cylon"))
		(c_supercrisis (p_getlayerpos "SuperCrisis"))
		(cylon nil)
		(playerid nil)
		(cylonoffset nil)
		(scused 0)
	)
	
	(while (not (null? myvalues))
		(case (string->symbol (cadr myvalues))
			((C) (set! cylonoffset (p_getused "Cylon")))
			((LS) (set! cylonoffset 2))
			((LH) (set! cylonoffset 3))
			((S) (set! cylonoffset 2))
			((L) (set! cylonoffset 4))	; Motives - Sympathetic for now
		)

		(MoveTokenToPlayer (+ c_cylonpos cylonoffset) (car myvalues))
		(when (string=? "S" (cadr myvalues)) (MoveTokenToPlayer (+ c_cylonpos 5) (car myvalues)) )	; Sympathetic Cylon banner
		(when (= (cadddr myvalues) 1) (MoveTokenToPlayer (+ c_cylonpos 6) (car myvalues)) )			; Infiltrator

		; Super-Crisis Cards
		(when (> (caddr myvalues) 0)	
			; find first available SC and use it...
			(set! scused (p_getused "SuperCrisis"))
			(gimp-drawable-set-visible (vector-ref mylayers (+ c_supercrisis scused)) TRUE)
			(gimp-layer-translate (vector-ref mylayers (+ c_supercrisis scused )) 0 (* cardoffsetY (-- (car myvalues))))
			(gimp-text-layer-set-text (vector-ref mylayers (+ c_supercrisis scused)) (number->string (caddr myvalues)))
			(gimp-drawable-set-visible (vector-ref mylayers (+ c_supercrisis scused 1)) TRUE)
			(gimp-layer-translate (vector-ref mylayers (+ c_supercrisis scused 1)) 0 (* cardoffsetY (-- (car myvalues))))
		) ;when

		(set! myvalues (cddddr myvalues))
	) ;while
) ;let*
) ;define


(define (bsgp-Damage myvalues)
; show galactica damage tokens
(let*
	(
;		(c_damagetxtpos (p_getlayerpos "DamageCntr"))
;		(c_damagedisppos (p_getlayerpos "DamageDispToken"))
		(c_damagepos (p_getlayerpos "DamageToken"))
		(damoff nil)
;		(dmgcnt 0)
	)
	(while (not (null? myvalues))
		(set! damoff 0)
		(while (< damoff 10)
			(when (string=5? (car (gimp-layer-get-name (vector-ref mylayers (+ c_damagepos damoff)))) (car myvalues))
				(gimp-drawable-set-visible (vector-ref mylayers (+ c_damagepos damoff)) TRUE)
				(set! damoff 10)
;				(set! dmgcnt (++ dmgcnt))
			)
			(set! damoff (++ damoff))
		) ;while
		(set! myvalues (cdr myvalues))
	) ;while
;	(gimp-drawable-set-visible (vector-ref mylayers c_damagetxtpos) TRUE)
;	(gimp-drawable-set-visible (vector-ref mylayers c_damagedisppos) TRUE)
;	(bsgp-Counters (list dmgcnt) 12)
) ;let*
) ;define

(define (bsgp-Distance myvalues)
(let*
	(
		(c_jumppos (p_getlayerpos "JumpDistance"))
		(jumpcnt 0)
		(distance 0)
		(disttmp 0)
	)
	(while (not (null? myvalues))
		(case (string->symbol (car myvalues))
			((LD)
				(gimp-drawable-set-visible (vector-ref mylayers (+ c_jumppos (* 5 jumpcnt))) TRUE)
				(gimp-text-layer-set-text (vector-ref mylayers (+ c_jumppos (* 5 jumpcnt))) "LEGENDARY")
				(gimp-drawable-set-visible (vector-ref mylayers (+ c_jumppos (* 5 jumpcnt) 2)) TRUE)
				(set! distance (++ distance))
			) ; Legendary Discovery
			((LT)
				(gimp-drawable-set-visible (vector-ref mylayers (+ c_jumppos (* 5 jumpcnt))) TRUE)
				(gimp-text-layer-set-text (vector-ref mylayers (+ c_jumppos (* 5 jumpcnt))) "ROAD LESS TRAVELED")
				(gimp-drawable-set-visible (vector-ref mylayers (+ c_jumppos (* 5 jumpcnt) 2)) TRUE)
				(set! distance (++ distance))
			)	; The Road Less Traveled
			((DP)
				(gimp-drawable-set-visible (vector-ref mylayers (+ c_jumppos (* 5 jumpcnt))) TRUE)
				(gimp-text-layer-set-text (vector-ref mylayers (+ c_jumppos (* 5 jumpcnt))) "DIGGING UP THE PAST")
				(gimp-drawable-set-visible (vector-ref mylayers (+ c_jumppos (* 5 jumpcnt) 2)) TRUE)
				(set! distance (++ distance))
			)	; The Road Less Traveled
			((SH)
				(gimp-drawable-set-visible (vector-ref mylayers (+ c_jumppos (* 5 jumpcnt))) TRUE)
				(gimp-text-layer-set-text (vector-ref mylayers (+ c_jumppos (* 5 jumpcnt))) "THE SEARCH FOR HOME")
				(gimp-drawable-set-visible (vector-ref mylayers (+ c_jumppos (* 5 jumpcnt) 3)) TRUE)
				(set! distance (+ 2 distance))
			)	; The Road Less Traveled
			((FE)
				(gimp-drawable-set-visible (vector-ref mylayers (+ c_jumppos (* 5 jumpcnt))) TRUE)
				(gimp-text-layer-set-text (vector-ref mylayers (+ c_jumppos (* 5 jumpcnt))) "FRAK EARTH")
				(gimp-drawable-set-visible (vector-ref mylayers (+ c_jumppos (* 5 jumpcnt) 2)) TRUE)
				(set! distance (-- distance))
			)	; Frak Earth
			(else 
				(set! disttmp (car myvalues))
				(when (string? disttmp) (set! disttmp (string->number disttmp)))
				(gimp-drawable-set-visible (vector-ref mylayers (+ c_jumppos (* 5 jumpcnt) disttmp 1)) TRUE)
				(set! distance (+ distance (abs disttmp)))
			) ;else
		) ;case
		(set! jumpcnt (++ jumpcnt))
		(set! myvalues (cdr myvalues))
	) ;while
	(bsgp-Counters (list distance) (p_getlayerpos "Distance"))
) ;let
) ;define


(define (bsgp-BoardSpecial myvalues)
; show special board conditions (Ambush, Jammed, etc...)
(let*
	(
		(c_specpos (p_getlayerpos "Special"))
		(specoff nil)
		(hoffset nil)
		(voffset nil)
	)
	(while (not (null? myvalues))
		(if (string=5? (car myvalues) "HUB D")
			(gimp-drawable-set-visible (vector-ref mylayers (p_getlayerpos "HubDestroyed")) TRUE)
			(if (string=5? (car myvalues) "COLON") ;check for colonial one
				(gimp-drawable-set-visible (vector-ref mylayers (p_getlayerpos "ColonialOneDestroyed")) TRUE)
				(if (string=5? (car myvalues) "PEGAS") ;check for Pegasus
					(gimp-drawable-set-visible (vector-ref mylayers (p_getlayerpos "PegasusDestroyed")) TRUE)
					(begin
						(if (even? specialcnt)
							(set! hoffset 0)
							(set! hoffset 1)
						)
						(set! voffset (quotient specialcnt 2))
						(set! specoff 0)
						(while (< specoff 11)
							(when (string=5? (car (gimp-layer-get-name (vector-ref mylayers (+ c_specpos specoff)))) (car myvalues))
								(begin
									(gimp-drawable-set-visible (vector-ref mylayers (+ c_specpos specoff)) TRUE)
									(gimp-layer-translate (vector-ref mylayers (+ c_specpos specoff)) (* hoffset 700) (* voffset 36))
									(set! specialcnt (++ specialcnt))
									(set! specoff 11)
								)
							) ;when
							(set! specoff (++ specoff))
						) ;while
					) ;begin
				) ;if
			) ;if
		) ; if
		(set! myvalues (cdr myvalues))
	) ;while
) ;let
) ;define

(define (bsgp-SearchForHome myvalues)
(let*
	(
		(rebel_overlay (car myvalues))
		(mission_name (string-append "MISSION: " (cadr myvalues)))
		(mission_side (caddr myvalues))
		(cntr nil)
	)
	(begin
		; First, set the Rebel Basestar Token (Human/Cylon) or the Filter (before the Cylon Civil War Mission is played)
		(cond ((string=? rebel_overlay "Unallied") (gimp-layer-set-visible (vector-ref mylayers (+ (p_getlayerpos "Filter") 5)) 1))
			  ((string=? rebel_overlay "Human") (gimp-layer-set-visible (vector-ref mylayers (p_getlayerpos "RebelBasestarToken")) 1))
			  ((string=? rebel_overlay "Cylon") (gimp-layer-set-visible (vector-ref mylayers (+ (p_getlayerpos "RebelBasestarToken") 1)) 1))
		) ; cond
		; Now, we acivate and place the current mission layer based on the ever-mobile Demetrius board
		(set! cntr 0)
		(while (< cntr 9)
			(when (string=? mission_name (car (gimp-drawable-get-name (vector-ref mylayers (+ (p_getlayerpos "CurrentMission") cntr)))))
				(gimp-layer-set-visible (vector-ref mylayers (+ (p_getlayerpos "CurrentMission") cntr)) 1) ; Activate the current mission layer
				(gimp-layer-set-offsets (vector-ref mylayers (+ (p_getlayerpos "CurrentMission") cntr)) ; Reposition the current mission layer based on Demetrius
					(+ (car (gimp-drawable-offsets (vector-ref mylayers (p_getlayerpos "Demetrius")))) 610)
					(+ (cadr (gimp-drawable-offsets (vector-ref mylayers (p_getlayerpos "Demetrius")))) 45)
			    )
				(set! cntr 9)
			) ;when
			(set! cntr (++ cntr))
		) ;while
		; Last, IF the card needs this info, place the "face up" or "face down" layer, but only for Search for Home and Digging up the Past missions
		(cond
			((and (string-ci=? mission_side "Passed") (or (string-ci=? mission_name "MISSION: The Search for Home") (string-ci=? mission_name "MISSION: Digging Up the Past"))) (begin
				(gimp-layer-set-visible (vector-ref mylayers (p_getlayerpos "CurrentMissionStatus")) 1)
				(gimp-layer-set-offsets (vector-ref mylayers (p_getlayerpos "CurrentMissionStatus")) 
					(+ (car (gimp-drawable-offsets (vector-ref mylayers (p_getlayerpos "Demetrius")))) 610)
					(+ (cadr (gimp-drawable-offsets (vector-ref mylayers (p_getlayerpos "Demetrius")))) 185)
			    )
			))
			((and (string-ci=? mission_side "Failed") (or (string-ci=? mission_name "MISSION: The Search for Home") (string-ci=? mission_name "MISSION: Digging Up the Past"))) (begin
				(gimp-layer-set-visible (vector-ref mylayers (+ (p_getlayerpos "CurrentMissionStatus") 1)) 1)
				(gimp-layer-set-offsets (vector-ref mylayers (+ (p_getlayerpos "CurrentMissionStatus") 1))
					(+ (car (gimp-drawable-offsets (vector-ref mylayers (p_getlayerpos "Demetrius")))) 610)
					(+ (cadr (gimp-drawable-offsets (vector-ref mylayers (p_getlayerpos "Demetrius")))) 185)
			    )
			))
		) ; cond
	)
) ; let
) ;define

;	(gimp-drawable-set-visible (vector-ref mylayers (+ (p_getlayerpos "CurrentMission") (car myvalues))) 1)

(define (bsgp-Assignments myvalues)
; show player assignements
(let*
	(
		(c_asgnpos (p_getlayerpos "Assign"))
		(asgnoff nil)
		(asgnname nil)
		(asgnid nil)
	)
	(while (not (null? myvalues))
		(set! asgnname (car myvalues))
		(set! asgnid (-- (cadr myvalues)))
		(set! asgnoff 0)
		(while (< asgnoff 6)
			(when (string=5? (car (gimp-layer-get-name (vector-ref mylayers (+ c_asgnpos asgnoff)))) asgnname)
				(gimp-drawable-set-visible (vector-ref mylayers (+ c_asgnpos asgnoff)) TRUE)
				(gimp-layer-translate (vector-ref mylayers (+ c_asgnpos asgnoff)) 0 (- (* asgnid cardoffsetY) (* (vector-ref asgncnt asgnid) 32)))
				(vector-set! asgncnt asgnid (++ (vector-ref asgncnt asgnid)))
				(set! asgnoff 6)
			) ;when
			(set! asgnoff (++ asgnoff))
		) ;while
		(set! myvalues (cddr myvalues))
	) ;while
) ;let
) ;bsgp-Assignements
;

(define (bsgp-Players myvalues useDB) 
; Players is of the form (Players (<locname> <locname> <locname> <locname> <locname> [...]))
; where <locname> is the string name of the location of that player...
(let*
	(
		(c_playerpos (p_getlayerpos "PlayerToken"))
		(lockey (vector '("Press Room" 185 210) '("President's Office" 340 210) '("Administration" 495 200)
			'("Caprica" 810 220) '("Cylon Fleet" 920 220) '("Human Fleet" 1030 220) '("Resurrection Ship" 1140 220) 
			'("Basestar Bridge" 345 220)
			'("Weapons Control" 475 765) '("Communications" 645 765) '("Research Lab" 815 765) '("Sickbay" 1155 765)
			'("FTL Control" 305 860) '("Armory" 985 860)
			'("Command" 475 960) '("Admiral's Quarters" 645 960) '("Hangar Deck" 815 960) '("Brig" 1155 960)
			'("Pegasus CIC" 40 145) '("Airlock" 240 170) '("Main Batteries" 445 170) '("Engine Room" 655 145)
			'("Medical Center" 1630 585) '("Resistance HQ" 1785 585) 
			'("Detention" 1625 780) '("Occupation Authority" 1790 785) '("Breeder's Canyon" 1935 785) '("Shipyard" 2080 785)
			'("Quorum Chamber" 95 210) '("Hub Destroyed" 1140 220)
			'("Bridge" 55 110) '("Tactical Plot" 245 110) '("Captain's Cabin" 425 110)
			'("Hybrid Tank" 95 110) '("Datastream" 345 140) '("Raider Bay" 590 110)
			'("Stranded on Caprica") '("Eliminated")
			'("Sector 1") '("Sector 2") '("Sector 3") '("Sector 4") '("Sector 5") '("Sector 6") )
		)

; '("Engine Room" 2cardoffsetY 1230)
		(loccnt (make-vector (vector-length lockey) 0))
		(plyrloc '())
		(plyrpos c_playerpos)
		(locoff nil)
		(plyrfnd nil)
		(locid nil)
		(cnt nil)
		(offset nil)
		(diff nil)
		(offlst nil)
		(c_pwidth 100)
		(pilotname nil)
		(pilotpos nil)
		(vipertype '())
		(c_pilotpos nil)
		(coloff 0)
		(c_colonialoneend 2)	; The original C1 locations shift to the right with Daybreak.
		(c_basestarbridge 7) 	; Basestar bridge moves if there are too many boards in play.
		(c_pegasusstart 18)     ; Pegasus now also moves!
		(c_demetriusstart 30)	; Demetrius moves all the time
		(c_rbbstart 33)			; Rebel Basestar moves all the time too
		(c_stranded 36)
		(c_eliminated 37)
		(c_sectorstart 38)		; 38 not-Space Locations
		(pilotloc #( ((155 1090) (155 800) (250 750)) ((655 515) (655 595) (655 675))
			((965 515) (965 595) (965 675)) (  (1230 730) (1315 960) (1250 1150))
			((965 1280) (965 1360) (965 1440)) ((655 1280) (655 1360) (655 1440) )))
		(sector nil)
		(myloc nil)
		(boardoffsetX nil)
		(boardoffsetY nil)
	)
	(while (not (null? myvalues))
		(set! locoff 0)			; iteration counter/location ID
		(set! plyrfnd -1)	
		(while (< locoff (vector-length lockey))
			(when (string=5? (car myvalues) (car (vector-ref lockey locoff)))	; 5-Char match
				(set! plyrfnd locoff)											; Location match ID
				(logit (car myvalues))
				(logit plyrfnd)
				(when (>= plyrfnd c_sectorstart)		; pilot in space
					(if (string=? (car myvalues) (car (vector-ref lockey locoff)))	
						(set! vipertype (append vipertype (list 0))) ;exact match means we're in a standard viper
						(if	(string=? (car myvalues) (string-append (car (vector-ref lockey locoff)) "*"))
							(set! vipertype (append vipertype (list 1))) 	; Viper MkVIIs append a *
							(set! vipertype (append vipertype (list 2)))	; Assault Raptors append a !
						)
					)
;					(when (not (list? vipertype)) (set! vipertype (list vipertype)))
				)	; Pilot
				(set! locoff (vector-length lockey))	; Quick way to exit the while
			);when
			(set! locoff (++ locoff))
		) ;while
		(vector-set! loccnt plyrfnd (++ (vector-ref loccnt plyrfnd)))	; loccnt is a vector for counting the number of players in each Location. This increments that count for the current player.
		(set! plyrloc (append plyrloc (list plyrfnd)))	; plyrloc is a vector of each player's locIDs
		
		(set! myvalues (cdr myvalues))
	) ;while
	
	; set up the offsets based on the number of tokens in a given location
	(set! locid 0)
	(while (< locid c_sectorstart)	;ignore the sectors
		(set! cnt (vector-ref loccnt locid))	; Fetch the number of number of players in locid
		(when (> cnt 0)
			(if (= cnt 1)
				(set! offlst '(0))
				(begin
					(set! offset (* (* (/ (-- cnt) cnt) c_pwidth) -1))
					(set! diff (* (/ 2 cnt) c_pwidth))
					(set! offlst '())
					(while (> cnt 0)
						(set! offlst (append offlst (list offset)))
						(set! offset (+ offset diff))
						(set! cnt (-- cnt))
					) ;while
				) ;begin
			) ;if
			(vector-set! loccnt locid offlst)	; replaces the count of players in a location with a list of offsets. But locations with 0 or 1 player both have an entry of 0?
		) ;when
		(set! locid (++ locid))
	) ;while

	(set! locid 1)
	; now actually place the tokens.
	(while (not (null? plyrloc))
		(set! locid (car plyrloc))
		(cond   ((and (>= locid c_pegasusstart) (<= locid (+ c_pegasusstart 3))) (begin
					(set! boardoffsetX (car (gimp-drawable-offsets (vector-ref mylayers (p_getlayerpos "Pegasus")))))
					(set! boardoffsetY (cadr (gimp-drawable-offsets (vector-ref mylayers (p_getlayerpos "Pegasus"))))))
				)
				((= locid c_basestarbridge) (begin
					(set! boardoffsetX (car (gimp-drawable-offsets (vector-ref mylayers (p_getlayerpos "CylonFleet")))))
					(set! boardoffsetY (cadr (gimp-drawable-offsets (vector-ref mylayers (p_getlayerpos "CylonFleet"))))))
				)
				((and (>= locid c_demetriusstart) (<= locid (+ c_demetriusstart 2))) (begin
					(set! boardoffsetX (car (gimp-drawable-offsets (vector-ref mylayers (p_getlayerpos "Demetrius")))))
					(set! boardoffsetY (cadr (gimp-drawable-offsets (vector-ref mylayers (p_getlayerpos "Demetrius"))))))
				)
				((and (>= locid c_rbbstart) (<= locid (+ c_rbbstart 2))) (begin
					(set! boardoffsetX (car (gimp-drawable-offsets (vector-ref mylayers (p_getlayerpos "RebelBasestar")))))
					(set! boardoffsetY (cadr (gimp-drawable-offsets (vector-ref mylayers (p_getlayerpos "RebelBasestar"))))))
				)
				(else (begin
					(set! boardoffsetX (car (gimp-drawable-offsets (vector-ref mylayers (p_getlayerpos "MainBoard")))))
					(set! boardoffsetY (cadr (gimp-drawable-offsets (vector-ref mylayers (p_getlayerpos "MainBoard"))))))
				)
		) ; cond
;		(if (= locid c_basestarbridge)
;			(begin
;				(set! boardoffsetX (car (gimp-drawable-offsets (vector-ref mylayers (p_getlayerpos "CylonFleet")))))
;				(set! boardoffsetY (cadr (gimp-drawable-offsets (vector-ref mylayers (p_getlayerpos "CylonFleet")))))
;			)
;			(begin
;				(set! boardoffsetX (car (gimp-drawable-offsets (vector-ref mylayers (p_getlayerpos "MainBoard")))))
;				(set! boardoffsetY (cadr (gimp-drawable-offsets (vector-ref mylayers (p_getlayerpos "MainBoard")))))
;			)
;		)
		(if (and (<= locid c_colonialoneend) useDB)	; Daybreak Colonial One locations are shifted right.
			(set! coloff (+ 75 (* locid 5)))
			(set! coloff 0)
		)
		(if (< locid c_stranded)
			; "normal" shipboard locations
			(begin
				(gimp-drawable-set-visible (vector-ref mylayers plyrpos) TRUE)
				(gimp-layer-set-offsets (vector-ref mylayers plyrpos) 
					(+ (cadr (vector-ref lockey locid)) (car (vector-ref loccnt locid)) boardoffsetX coloff)
					(+ (caddr (vector-ref lockey locid)) boardoffsetY))
				(vector-set! loccnt locid (cdr (vector-ref loccnt locid)))
			)
			(if (= locid c_stranded)
				; Helo is stranded
				(begin
					(gimp-drawable-set-visible (vector-ref mylayers (p_getlayerpos "Stranded")) TRUE)
					(gimp-layer-translate (vector-ref mylayers (p_getlayerpos "Stranded")) 0 (* (- plyrpos c_playerpos) cardoffsetY))
				)
				(if (= locid c_eliminated)
					; Eliminated Player (Exodus Ionian Nebula only)
					()
					; pilot in space
					(begin
						; get the name of the pilot so we can find the right pilot token
						(if (= (car vipertype) 0)
							(begin
								(set! pilotname (string-append "Pilot " (car (gimp-layer-get-name (vector-ref mylayers plyrpos)))))
								(set! c_pilotpos (p_getlayerpos "Pilot"))
							)
							(if	(= (car vipertype) 1)
								(begin
									(set! pilotname (string-append "Pilot2 " (car (gimp-layer-get-name (vector-ref mylayers plyrpos)))))
									(set! c_pilotpos (p_getlayerpos "PilotMkVII"))
								)
								(begin
									(set! pilotname (string-append "Pilot3 " (car (gimp-layer-get-name (vector-ref mylayers plyrpos)))))
									(set! c_pilotpos (p_getlayerpos "PilotAR"))
								)
							)
						)
						(set! vipertype (cdr vipertype))
						(set! plyrfnd -1)
						(set! pilotpos c_pilotpos)
						(while (< pilotpos (+ c_pilotpos 13))
							(when (string=5? pilotname (car (gimp-layer-get-name (vector-ref mylayers pilotpos))))
								(set! plyrfnd pilotpos)
								(set! pilotpos (+ c_pilotpos 13))
							) ;when
							(set! pilotpos (++ pilotpos))
						) ;while
						; so now we have the token for the pilot...show it and position it appropriately with a viper
						(set! sector (- locid c_sectorstart))  ;technically, this is sector-1.
						(set! myloc (car (vector-ref pilotloc sector)))
						(vector-set! pilotloc sector (cdr (vector-ref pilotloc sector)))
						(gimp-drawable-set-visible (vector-ref mylayers plyrfnd) TRUE)
						(gimp-layer-set-offsets (vector-ref mylayers plyrfnd) (+ (car myloc) boardoffsetX) (+ (cadr myloc) boardoffsetY))
					
;						(set! pilotcnt (++ pilotcnt))
					) ;begin
				); if
			) ;if
		) ;if
		(set! locid (++ locid))
		(set! plyrpos (++ plyrpos))
		(set! plyrloc (cdr plyrloc))
	) ;while
) ;let
) ;bsgp-Players
;

(define (bsgp-Allies myvalues useDB)
; this will have to behave similarly to bsgp-Players
(let*
	(
		(lockey (vector '("Press Room" 185 210) '("President's Office" 340 210) '("Administration" 495 200)
			'("Weapons Control" 475 765) '("Communications" 645 765) '("Research Lab" 815 765) '("Sickbay" 1155 765)
			'("FTL Control" 305 860) '("Armory" 985 860)
			'("Command" 475 960) '("Admiral's Quarters" 645 960) '("Hangar Deck" 815 960) '("Brig" 1155 960)
			'("Pegasus CIC" 1610 1230) '("Airlock" 1810 1255) '("Main Batteries" 2015 1255) '("Engine Room" 2225 1230) )
		)
		(boardoffsetX nil)
		(boardoffsetY nil)
		(c_allypos (p_getlayerpos "Allies"))
		(allyname nil)
		(allyloc nil)
		(foundally nil)
		(prevloc '())
		(tmpprev nil)
		(cntr nil)
		(c_colonialoneend 2)	; The original C1 locations shift to the right with Daybreak.
		(locoff nil)
		(myoffX nil)
		(myoffY nil)
	)
	; If we have Allies, we have Brig/Sickbay Trauma
	(gimp-layer-set-visible (vector-ref mylayers (+ (p_getlayerpos "CrisisToken") 4)) TRUE)

	; Ally placement is referenced to the Main Game Board.
	(set! boardoffsetX (car (gimp-drawable-offsets (vector-ref mylayers (p_getlayerpos "MainBoard")))))
	(set! boardoffsetY (cadr (gimp-drawable-offsets (vector-ref mylayers (p_getlayerpos "MainBoard")))))
	
	(while (not (null? myvalues))
		; get the name of the current ally
		; walk the cards until it's found
		(set! allyname (car myvalues))		; Ally name 
		(set! allyloc (cadr myvalues))		; Location string
		(set! myoffY 170)
		(set! tmpprev prevloc)
		(while (not (null? tmpprev))
			(when (string=? allyloc (car tmpprev))	(set! myoffY (- myoffY 75)) )
			(set! tmpprev (cdr tmpprev))
		) ;while
		(set! foundally 0)
		(set! cntr 0)
		(while (< cntr 35)
			(when (string=? allyname (car (gimp-drawable-get-name (vector-ref mylayers (+ c_allypos cntr)))))
				(gimp-drawable-set-visible (vector-ref mylayers (+ c_allypos cntr)) TRUE)	; Ally is visible
				(set! foundally 1)
				; now put the ally in the right place
				(set! locoff 0)
				(while (< locoff (vector-length lockey))
					(when (string=? allyloc (car (vector-ref lockey locoff)))
						; for now, just put the person in the location, later deal with offsets for multiples in a loc
						(if (and (<= locoff c_colonialoneend) useDB)
							(set! myoffX (+ 145 (* locoff 5)))
							(set! myoffX 70)
						)
						(gimp-layer-set-offsets (vector-ref mylayers (+ c_allypos cntr)) 
							(+ (cadr (vector-ref lockey locoff)) boardoffsetX myoffX)
							(+ (caddr (vector-ref lockey locoff)) boardoffsetY myoffY))
						(set! prevloc (append prevloc (list allyloc)))
						(set! locoff (vector-length lockey))
					);when
					(set! locoff (++ locoff))
				) ;while
				(set! cntr 35)
			) ;when
			(set! cntr (++ cntr))
		) ;while
		(when (= foundally 0)	(logit (string-append "Unable to locate ally: " allyname)))

		(set! myvalues (cddr myvalues))
	) ;while
); let
); bsgp-Allies

;
(define (bsgp-Sector sectordata mainboard showships)
;Sector identifies ship deployments, excluding piloted vipers (???)
;"Sector",<sector#>,<HeavyCnt>,<RaiderCnt>,<ViperCnt>[,<ViperMkVIICnt>][,<AssaultRaptorCnt>]
;mainboard = FALSE -> Cylon Fleet
(let*
	(
		(sector nil)
		(dmglst nil)
		(shipcnt nil)
	)
	(if (= mainboard TRUE)
		(set! sector (car sectordata))
		(set! sector (+ (car sectordata) 6))
	)
	(set! sectordata (cdr sectordata))
	
(logit sectordata)
	; Heavy Raiders
	(when (> (car sectordata) 0) (bsgp-ShipsHRV sector 0 (car sectordata) showships))
	
	; Raiders
	(when (> (cadr sectordata) 0) (bsgp-ShipsHRV sector 1 (cadr sectordata) showships))
	
	(when (= mainboard TRUE)
		; vipers
		(when (> (caddr sectordata) 0) (bsgp-ShipsHRV sector 2 (caddr sectordata) showships))
			
		; Viper Mark VII's
		(when (not (null? (cdddr sectordata)))
			(when (> (cadddr sectordata) 0) (bsgp-ShipsHRV sector 3 (cadddr sectordata) showships))
		)
			
		; Assault Raptors
		(when (not (null? (cddddr sectordata)))
			(when (> (car (cddddr sectordata)) 0) (bsgp-ShipsHRV sector 5 (car (cddddr sectordata)) showships))
		)
	)
) ;let
) ;define
	
	
(define (bsgp-Basestar myvalues)
(let*
	(
		;basestarloc fmt:   list of sectors, in each sector, coord sets if either 1 or 2 basestars. Coord list is (X Y [Rot])
		(basestarloc #( #((30 850 1) (10 1130)) #((160 500) (480 500))
			#((1110 500) (790 500)) #((1400 790 1) (1410 1070)) 
			#((1110 1370) (790 1370)) #((160 1370) (480 1370)) 
			; cylon fleet
			#((10 260) (80 350)) #((50 100) (10 15)) 
			#((530 100) (570 15)) #((590 260) (550 320))
			#((580 630) (530 560)) #((30 630) (80 560))
			))
		(baseloc nil)
		(basepos (p_getlayerpos "Basestar"))
		(baserot nil)
		(damage nil)
		(damagepos nil)
		(damageoffset 0)
		(dmgOff1 37)
		(dmgOff2 106)
		(basecnt 0)
		(sector nil)
		(dmglst nil)
		(boardoffsetX nil)
		(boardoffsetY nil)
	)
	(set! sector (car myvalues))
	(if (< sector 0) 
		(begin ; deploy n the Cylon Fleet
			(set! sector (+ (* sector -1) 6))
			(set! boardoffsetX (car (gimp-drawable-offsets (vector-ref mylayers (p_getlayerpos "CylonFleet")))))
			(set! boardoffsetY (cadr (gimp-drawable-offsets (vector-ref mylayers (p_getlayerpos "CylonFleet")))))
		)
		(begin
			(set! boardoffsetX (car (gimp-drawable-offsets (vector-ref mylayers (p_getlayerpos "MainBoard")))))
			(set! boardoffsetY (cadr (gimp-drawable-offsets (vector-ref mylayers (p_getlayerpos "MainBoard")))))
		)
	); if
	(set! dmglst (cdr myvalues))
	(when (= basestarfirst sector) (set! basecnt 1)) ;is there already a basestar in this sector?
	(set! basestarfirst sector)
	
	(set! basepos (+ (p_getlayerpos "Basestar") (p_getused "Basestar")))
	(set! baseloc (vector-ref (vector-ref basestarloc (-- sector)) basecnt))

	(gimp-drawable-set-visible (vector-ref mylayers basepos) TRUE)
	(when (> sector 6) 
		(gimp-layer-scale (vector-ref mylayers basepos) (* (car (gimp-drawable-width (vector-ref mylayers basepos))) imgscale) (* (car (gimp-drawable-height (vector-ref mylayers basepos))) imgscale) TRUE) 
		(set! dmgOff1 (* 37 imgscale))
		(set! dmgOff2 (* 106 imgscale))
	)
		
	(if (not (null? (cddr baseloc))) 
		(begin
			(gimp-drawable-transform-rotate-simple (vector-ref mylayers basepos) ROTATE-90 TRUE 0 0 FALSE)
			(set! baserot 1)
		)
		(set! baserot 0)
	) ;if
	(gimp-layer-set-offsets (vector-ref mylayers basepos) (+ (car baseloc) boardoffsetX) (+ (cadr baseloc) boardoffsetY))
	; if we have damage to the basestars... 
	(set! damage nil)

	(while (not (null? dmglst))
		(set! damage (car dmglst))
		(set! dmglst (cdr dmglst))

		;find the right token
		(set! damagepos (p_getlayerpos "BasestarDmg"))
		(while (> (p_getlayerpos "Basestar") damagepos)
			(when (string=5? damage (car (gimp-layer-get-name (vector-ref mylayers damagepos))))

				(when (> sector 6)
					(gimp-layer-scale (vector-ref mylayers damagepos) (* (car (gimp-drawable-width (vector-ref mylayers damagepos))) imgscale) (* (car (gimp-drawable-height (vector-ref mylayers damagepos))) imgscale) TRUE) 
				)
				(gimp-drawable-set-visible (vector-ref mylayers damagepos) TRUE)
				(if (= baserot 1)
					(gimp-layer-set-offsets (vector-ref mylayers damagepos) (+ (car baseloc) dmgOff1 damageoffset boardoffsetX) (+ (cadr baseloc) dmgOff2 damageoffset boardoffsetY))
					(gimp-layer-set-offsets (vector-ref mylayers damagepos) (+ (car baseloc) dmgOff2 damageoffset boardoffsetX) (+ (cadr baseloc) dmgOff1 damageoffset boardoffsetY))
				) ;if
				(if (> sector 6)
					(set! damageoffset (* imgscale 30))
					(set! damageoffset 30)
				)
				
				(set! damagepos (+ damagepos 4))
			) ;when
			(set! damagepos (++ damagepos))
		) ;while
	) ;when
) ;let
) ;bsgp-Basestar

;
(define (bsgp-ShipsHRV sector shiptype shipcnt showships)
(let*
	(
		(shiploc #( #( (10 780) (480 580) (800 580) (1375 730) (945 1460) (468 1460) 
						(0 500) (230 210) (400 210) (650 500) (400 680) (230 680))	; Heavy
			#( (40 700) (510 510) (820 510) (1400 665) (920 1395) (460 1395) 
				(10 430) (250 150) (420 150) (610 430) (420 620) (250 620))			; Raider
			#( (30 1165) (600 640) (825 640) (1385 1085) (840 1240) (520 1230)) 	; Viper
			#( (30 1225) (420 645) (825 710) (1320 1130) (820 1340) (500 1340)) 	; MkVII
			#( (5 600) (440 520) (760 520) (1300 690) (770 1370) (640 1370)) 		; Scar
			#( (30 1225) (265 640) (1010 600) (1395 1185) (820 1280) (520 1270))	)	; Assault Raptor - Originally from MkVII, but tweaked extensively
		)
		(shippos nil)
		(myloc nil)
		(cntpos nil)
		(used nil)
		(shiptextoffset nil)
		(boardoffsetX nil)
		(boardoffsetY nil)
	)
	(set! myloc (vector-ref (vector-ref shiploc shiptype) (-- sector)))	; Find the coordinate pair for the sector:shiptype pair 
	(case shiptype
		((0) (set! shippos (p_getlayerpos "HeavyRaider")) (set! used (p_getused "HeavyRaider")))	; Set the base token layer and find out how many tokens have been used previously.
		((1) (set! shippos (p_getlayerpos "Raider")) (set! used (p_getused "Raider")))
		((2) (set! shippos (p_getlayerpos "Viper")) (set! used (p_getused "Viper")))
		((3) (set! shippos (p_getlayerpos "ViperMkVII")) (set! used (p_getused "ViperMkVII")))
		((4) (set! shippos (p_getlayerpos "Scar")) (set! used 0))
		((5) (set! shippos (p_getlayerpos "AssaultRaptor")) (set! used (p_getused "AssaultRaptor")))
	) ;case
	(if (> sector 6) 
		(begin ; deploy n the Cylon Fleet
			(set! boardoffsetX (car (gimp-drawable-offsets (vector-ref mylayers (p_getlayerpos "CylonFleet")))))
			(set! boardoffsetY (cadr (gimp-drawable-offsets (vector-ref mylayers (p_getlayerpos "CylonFleet")))))
		)
		(begin
			(set! boardoffsetX (car (gimp-drawable-offsets (vector-ref mylayers (p_getlayerpos "MainBoard")))))
			(set! boardoffsetY (cadr (gimp-drawable-offsets (vector-ref mylayers (p_getlayerpos "MainBoard")))))
		)
	); if
	
	; If we're showing ship counts, and there are multiple ships
	(when (and (> shipcnt 1) (= showships 0))
		(set! cntpos (+ (vector-ref #(4 20 8 4 0 4) shiptype) shippos))	; Get the position of the count layer
		(when (and (or (= shiptype 0) (= shiptype 3) (= shiptype 5)) (>= used 2)) (set! cntpos (++ cntpos)))	; For count-limited ships (Heavy, VMkVII, AR), we grab the right count layer
		(when (or (= shiptype 1) (= shiptype 2)) (set! cntpos (+ cntpos (-- sector))))							; for sector-limited ships, we have a count for each Sector.

		(gimp-drawable-set-visible (vector-ref mylayers cntpos) TRUE)		; Enable the count layer.
		(if (> sector 6)
			(set! shiptextoffset (* (vector-ref #(130 100 110 120 0 110) shiptype) imgscale))		; Grab the offset of the text.
			(set! shiptextoffset (vector-ref #(130 100 110 120 0 110) shiptype))					; Scale the offset for the CFB
		)
		(gimp-layer-set-offsets (vector-ref mylayers cntpos) (+ (car myloc) shiptextoffset boardoffsetX) (+ (cadr myloc) boardoffsetY))	; Move the Couter to the right spot
		(gimp-text-layer-set-text (vector-ref mylayers cntpos) (string-append "x" (number->string shipcnt)))							; And set the text (xN).
		(when (> sector 6)																												; Scale the text for the CFB
			(gimp-layer-scale (vector-ref mylayers cntpos) (* (car (gimp-drawable-width (vector-ref mylayers cntpos))) imgscale) (* (car (gimp-drawable-height (vector-ref mylayers cntpos))) imgscale) TRUE) 
		)
	)
	(set! shippos (+ shippos used))
	(while (> shipcnt 0)
		(gimp-drawable-set-visible (vector-ref mylayers shippos) TRUE)														; Show the Ship token.
		(gimp-layer-set-offsets (vector-ref mylayers shippos) (+ (car myloc) boardoffsetX) (+ (cadr myloc) boardoffsetY))	; Move it.
		(when (> sector 6)																									; Scale it on the CFB.
			(gimp-layer-scale (vector-ref mylayers shippos) (* (car (gimp-drawable-width (vector-ref mylayers shippos))) imgscale) (* (car (gimp-drawable-height (vector-ref mylayers shippos))) imgscale) TRUE) 
		)

		(when (= showships 1) (set! myloc (map + myloc '(15 5))))	; If we're showing individual ships, add an offset. I guess we show all of them, even if we're showing a counter, and the lower ones are hidden.
		(set! shipcnt (-- shipcnt))
		(set! shippos (++ shippos))
	) ;while
) ;let*
) ;define
;
(define (bsgp-ShipsCivilians sector civlst)
(let*
	(
		(civloc #( (50 1300) (500 710) (1010 680) (1245 1205) (1100 1270) (180 1380) )) ;first was (130 1300)
		(civoff #( (45 -25) (45 0) (45 0) (45 25) (45 25) (45 -25) ))
		(myloc nil)
		(myoff nil)
		(civpos nil)
		(prevciv nil)
		(boardoffsetX nil)
		(boardoffsetY nil)
	)
	(set! myloc (vector-ref civloc (-- sector)))
	(set! myoff (vector-ref civoff (-- sector)))
	(set! prevciv (vector-ref civcnt (-- sector)))
	(set! boardoffsetX (car (gimp-drawable-offsets (vector-ref mylayers (p_getlayerpos "MainBoard")))))
	(set! boardoffsetY (cadr (gimp-drawable-offsets (vector-ref mylayers (p_getlayerpos "MainBoard")))))

	(while (> prevciv 0)
		(set! myloc (map + myloc myoff))
		(set! prevciv (-- prevciv))
	)
	(while (not (null? civlst))
		(set! civpos (+ (p_getlayerpos "Civilian") (- (char->integer #\L) (char->integer (string-ref (car civlst) 0)) )))
		(gimp-drawable-set-visible (vector-ref mylayers civpos) TRUE)
		(gimp-layer-set-offsets (vector-ref mylayers civpos) (+ (car myloc) boardoffsetX) (+ (cadr myloc) boardoffsetY) )

		(vector-set! civcnt (-- sector) (++ (vector-ref civcnt (-- sector))))
		(set! myloc (map + myloc myoff))
		(set! civlst (cdr civlst))
	) ;while
) ;let
) ;define
;

(define (bsgp-DamagedCivilians myvalues layerpos)
(let*
	(
		(cntr 0)
	)
	(while (not (null? myvalues))
		(when (> (car myvalues) 0)
			(gimp-drawable-set-visible (vector-ref mylayers (+ layerpos (+ cntr 3))) TRUE)
			(when (> (car myvalues) 1)
				(gimp-drawable-set-visible (vector-ref mylayers (+ layerpos cntr)) TRUE)
				(gimp-text-layer-set-text (vector-ref mylayers (+ layerpos cntr)) (number->string (car myvalues)))
				(when (= outlineoption TRUE)
					(outlineText (vector-ref mylayers (+ layerpos cntr)) 4 '(0 0 0))
					(set! mylayers (cadr (gimp-image-get-layers image)))
				)
			)
		)
		(set! cntr (++ cntr))
		(set! myvalues (cdr myvalues))
	)
)
)

(define (bsgp-DestroyedBasestar myvalues)
(let*
	(
		(basestar (car myvalues))
		(heavy (cadr myvalues))
	)
	(gimp-drawable-set-visible (vector-ref mylayers (p_getlayerpos "DestroyedBasestar")) basestar)
	(gimp-drawable-set-visible (vector-ref mylayers (+ (p_getlayerpos "DestroyedBasestar") 1)) heavy)
)
)

(define (bsgp-ConfigureBoard image objective usePeg useExo useCF useDB useRev)
; possible board configurations are:
; 1 - Base & Kobol/IN - DONE
; 2 - Pegasus & Kobol/IN  - DONE
; 3 - Pegasus & NC           - DONE
; 4 - Base & CF & Kobol/IN - DONE
; 5 - Pegasus & CF & Kobol/IN - DONE
; 6 - Pegasus & CF & NC - DONE
; 7 - Base & Earth - DONE
; 8 - Base & CF & Earth - DONE
; 9 - Pegasus & Earth - DONE
; 10 - Pegasus & CF & Earth - DONE
(let*
	(
		(destcnt 0)
		(auxcont 0)
		(cardoffsetY 225)
	)

	; set the objective cards appropriately
	(when (list? objective) (set! objective (car objective)))
	(gimp-drawable-set-visible (vector-ref mylayers (p_getlayerpos "FinalDest")) (btoint (string=? objective "Kobol")))
	(gimp-drawable-set-visible (vector-ref mylayers (+ (p_getlayerpos "FinalDest") 1)) (btoint (string=? objective "New Caprica")))
	(gimp-drawable-set-visible (vector-ref mylayers (+ (p_getlayerpos "FinalDest") 2)) (btoint (string=? objective "Ionian Nebula")))
	(gimp-drawable-set-visible (vector-ref mylayers (+ (p_getlayerpos "FinalDest") 3)) (btoint (string=? objective "Earth")))
	(gimp-drawable-set-visible (vector-ref mylayers (+ (p_getlayerpos "FinalDest") 4)) (btoint (string=? objective "Ionian Earth")))
	;(gimp-drawable-set-visible (vector-ref mylayers (+ (p_getlayerpos "FinalDest") 4)) (btoint (string=? objective "Colony")))
	
	; Show or hide the Cylon Overlay, Pegasus & Treachery
	(gimp-layer-set-visible (vector-ref mylayers (p_getlayerpos "CylonLocations")) (btoint (and usePeg (not useDB))))
	(gimp-layer-set-visible (vector-ref mylayers (+ (p_getlayerpos "CylonLocations") 1)) (btoint  useDB))
	(gimp-layer-set-visible (vector-ref mylayers (p_getlayerpos "Pegasus")) (btoint usePeg))
	(gimp-layer-set-visible (vector-ref mylayers (+ (p_getlayerpos "PoliticsDeck") 5)) (btoint (or usePeg useDB)))
	(gimp-layer-set-visible (vector-ref mylayers (+ (p_getlayerpos "PoliticsCntr") 5)) (btoint (or usePeg useDB)))
		
	; Show or hide New Caprica and its filter
	(gimp-drawable-set-visible (vector-ref mylayers (p_getlayerpos "NewCaprica")) (btoint (string=? objective "New Caprica")))
	(gimp-drawable-set-visible (vector-ref mylayers (+ (p_getlayerpos "Filter") 3)) (btoint (string=? objective "New Caprica")))

	; Show or hide the Cylon Fleet
	(gimp-drawable-set-visible (vector-ref mylayers (p_getlayerpos "CylonFleet")) (btoint useCF))

	; Show or hide the new Colonial One, Mutiny Deck
	;(gimp-layer-set-visible (vector-ref mylayers (p_getlayerpos "TreacheryDeck")) (btoint useDB))	; In case there isn't a Pegasus to provide it.
	(gimp-layer-set-visible (vector-ref mylayers (p_getlayerpos "ColonialOneDaybreak")) (btoint useDB))
	(gimp-layer-set-visible (vector-ref mylayers (+ (p_getlayerpos "CrisisCntr") 5)) (btoint useDB))	; Mutiny counter
	(gimp-layer-set-visible (vector-ref mylayers (+ (p_getlayerpos "CrisisToken") 5)) (btoint useDB))	; Mutiny deck
	; Do we need to add a Treachery deck slot if there's no Pegasus board? Probably.
	
	; Show or hide the Demetrius, Daybreak Rebel Basestar, Mission Deck, Mission Counter
	(gimp-layer-set-visible (vector-ref mylayers (p_getlayerpos "Demetrius" )) (btoint (or (string=? objective "Earth") (string=? objective "Ionian Earth"))))
	(gimp-layer-set-visible (vector-ref mylayers (p_getlayerpos "RebelBasestar" )) (btoint (or (string=? objective "Earth") (string=? objective "Ionian Earth"))))
	(gimp-layer-set-visible (vector-ref mylayers (+ (p_getlayerpos "CrisisCntr") 6)) (btoint (or (string=? objective "Earth") (string=? objective "Ionian Earth"))))
	(gimp-layer-set-visible (vector-ref mylayers (+ (p_getlayerpos "CrisisToken") 8)) (btoint (or (string=? objective "Earth") (string=? objective "Ionian Earth"))))
	
	; Show or hide the Faith Counter and deck placement layer
	(gimp-layer-set-visible (vector-ref mylayers (+ (p_getlayerpos "TreacheryDeck") 1)) (btoint useRev))
	(gimp-layer-set-visible (vector-ref mylayers (+ (p_getlayerpos "PoliticsCntr") 6)) (btoint useRev))

	; Show or hide the Revelations Rebel Basestar and filter
	;(gimp-drawable-set-visible (vector-ref mylayers (p_getlayerpos "RevRebel")) (btoint (string=? objective "Colony")))
	;(gimp-drawable-set-visible (vector-ref mylayers (+ (p_getlayerpos "Filter") 5)) (btoint (string=? objective "Colony")))

	; Show or hide the Colony Board and Filter
	;(gimp-drawable-set-visible (vector-ref mylayers (p_getlayerpos "Colony")) (btoint (string=? objective "Colony")))
	;(gimp-drawable-set-visible (vector-ref mylayers (+ (p_getlayerpos "Filter") 6)) (btoint (string=? objective "Colony")))
	; Set up the reserves - these don't move relative to the board, so there shouldn't be an issue if we place them before adjusting image size.
	(if useCF
		(begin 
			; Damaged Vipers don't have anything to do with Assault Raptors
			; Move the normal Vipers.
			(gimp-layer-translate (vector-ref mylayers (p_getlayerpos "ReserveToken")) -10 -15)		; Changed to a translation.
			(gimp-layer-translate (vector-ref mylayers (p_getlayerpos "Reserves")) 30 -55)

			; Show the MkVIIs
			(gimp-drawable-set-visible (vector-ref mylayers (+ (p_getlayerpos "ReserveToken") 3)) TRUE)	; Damaged MkVIIs are shown.
			(gimp-drawable-set-visible (vector-ref mylayers (+ (p_getlayerpos "Reserves") 3)) TRUE)		; Damaged MkVII count

			(if useDB
				; We have all four ship types.
				(begin
					; Move the normal Vipers to the far left.
					(gimp-layer-translate (vector-ref mylayers (+ (p_getlayerpos "ReserveToken") 1)) -60 0)		; Vipers move left.
					(gimp-layer-translate (vector-ref mylayers (+ (p_getlayerpos "Reserves") 1)) -60 0)

					; Move the MkVIIs left and show them.
					(gimp-drawable-set-visible (vector-ref mylayers (+ (p_getlayerpos "ReserveToken") 4)) TRUE)		; MkVIIs are shown.
					(gimp-drawable-set-visible (vector-ref mylayers (+ (p_getlayerpos "Reserves") 4)) TRUE)
					(gimp-layer-translate (vector-ref mylayers (+ (p_getlayerpos "ReserveToken") 4)) -50 0)			; And move left
					(gimp-layer-translate (vector-ref mylayers (+ (p_getlayerpos "Reserves") 4)) -50 0)

					; Move the Raptors left.
					(gimp-layer-translate (vector-ref mylayers (+ (p_getlayerpos "ReserveToken") 2)) -35 0)	; Raptors - We need to move these left.
					(gimp-layer-translate (vector-ref mylayers (+ (p_getlayerpos "Reserves") 2)) -35 0)

					; Show the Assault Raptors and move them to the right.
					(gimp-drawable-set-visible (vector-ref mylayers (+ (p_getlayerpos "ReserveToken") 5)) TRUE)		; Assault Raptors are shown.
					(gimp-drawable-set-visible (vector-ref mylayers (+ (p_getlayerpos "Reserves") 5)) TRUE)
					(gimp-layer-translate (vector-ref mylayers (+ (p_getlayerpos "ReserveToken") 5)) 40 0)			; And move right
					(gimp-layer-translate (vector-ref mylayers (+ (p_getlayerpos "Reserves") 5)) 40 0)

				)	; if useDB
				; No Assault Raptors
				(begin
					; Move the normal Vipers left.
					(gimp-layer-translate (vector-ref mylayers (+ (p_getlayerpos "ReserveToken") 1)) -30 0)		; Vipers move left.
					(gimp-layer-translate (vector-ref mylayers (+ (p_getlayerpos "Reserves") 1)) -30 0)

					; Move the Raptors right.
					(gimp-layer-translate (vector-ref mylayers (+ (p_getlayerpos "ReserveToken") 2)) 30 0)	; Raptors - We need to move these right for CFB games.
					(gimp-layer-translate (vector-ref mylayers (+ (p_getlayerpos "Reserves") 2)) 30 0)

					; Show the MkVIIs.
					(gimp-drawable-set-visible (vector-ref mylayers (+ (p_getlayerpos "ReserveToken") 4)) TRUE)		; MkVIIs are shown.
					(gimp-drawable-set-visible (vector-ref mylayers (+ (p_getlayerpos "Reserves") 4)) TRUE)
				)	; !useDB
			)
		)	; if useCF
		(when useDB
			; No Mark VIIs to deal with. 
			; Move Vipers left, Raptors more left, show Assault Raptors.
			(gimp-layer-translate (vector-ref mylayers (+ (p_getlayerpos "ReserveToken") 1)) -30 0)		; Vipers move left.
			(gimp-layer-translate (vector-ref mylayers (+ (p_getlayerpos "Reserves") 1)) -30 0)

			; Move Raptors left, to center.
			(gimp-layer-translate (vector-ref mylayers (+ (p_getlayerpos "ReserveToken") 2)) -90 0)	; Raptors - We need to move these left.
			(gimp-layer-translate (vector-ref mylayers (+ (p_getlayerpos "Reserves") 2)) -90 0)

			; Show Assault Raptors
			(gimp-drawable-set-visible (vector-ref mylayers (+ (p_getlayerpos "ReserveToken") 5)) TRUE)		; Assault Raptors are shown.
			(gimp-drawable-set-visible (vector-ref mylayers (+ (p_getlayerpos "Reserves") 5)) TRUE)
		); !useCF
	)

; 1 - Main Game Board only - no Pegasus, no CFB, no New Caprica, Earth, or Colony, no CCW. Decks on the left, MGB in the middle, characters on the right.
	(when (not (or usePeg useCF (or (string=? objective "Earth") (string=? objective "Ionian Earth"))))
(logit "ConfigureBoard 1 - Main Game Board only")
		
		; Move the turn indicator to the right.
		(gimp-layer-translate (vector-ref mylayers (p_getlayerpos "Turn")) 25 0)
		
		; Civilian Pool
		(gimp-layer-translate (vector-ref mylayers (p_getlayerpos "CivToken")) 25 0)
		(gimp-layer-translate (vector-ref mylayers (p_getlayerpos "CivCntr")) 25 0)

		; Crisis Deck
		(gimp-layer-set-offsets (vector-ref mylayers (p_getlayerpos "CrisisToken")) 1811 310)
		(gimp-layer-set-offsets (vector-ref mylayers (p_getlayerpos "CrisisCntr")) 1809 425)
	
		; Quorum Deck
		(gimp-layer-set-offsets (vector-ref mylayers (+ (p_getlayerpos "CrisisToken") 2)) 1811 710)
		(gimp-layer-set-offsets (vector-ref mylayers (+ (p_getlayerpos "CrisisCntr") 2)) 1809 825)
		
		; Super Crisis Deck
		(gimp-layer-set-offsets (vector-ref mylayers (+ (p_getlayerpos "CrisisToken") 3)) 1811 510)
		(gimp-layer-set-offsets (vector-ref mylayers (+ (p_getlayerpos "CrisisCntr") 4)) 1809 625)
		
		; Mutiny Deck
		(gimp-layer-set-offsets (vector-ref mylayers (+ (p_getlayerpos "CrisisToken") 5)) 1811 910)
		(gimp-layer-set-offsets (vector-ref mylayers (+ (p_getlayerpos "CrisisCntr") 5)) 1809 1025)

		; Faith Deck
		(gimp-layer-set-offsets (vector-ref mylayers (+ (p_getlayerpos "TreacheryDeck") 1)) 1807 1530)
		(gimp-layer-set-offsets (vector-ref mylayers (+ (p_getlayerpos "PoliticsCntr") 6)) 1856 1458)

		; Moving the Graveyard down to the bottom.
		(if useDB ; Rev requires Daybreak or Pegasus, and Pegasus doesn't use this section.
			(begin
				(gimp-layer-set-offsets (vector-ref mylayers (p_getlayerpos "Graveyard")) 1569 1167)
				(let*
					(
						(iter 0)
						(baselayer (p_getlayerpos "DamagedCivs"))
					)
					(while (< iter 8)
						(gimp-layer-translate (vector-ref mylayers (+ baselayer iter)) -360 1100)
						(set! iter (++ iter))
					)
				)
			)
			(begin
				(gimp-layer-set-offsets (vector-ref mylayers (p_getlayerpos "Graveyard")) 1569 1280)
				(let*
					(
						(iter 0)
						(baselayer (p_getlayerpos "DamagedCivs"))
					)
					(while (< iter 8)
						(gimp-layer-translate (vector-ref mylayers (+ baselayer iter)) -360 1215)
						(set! iter (++ iter))
					)
				)
			)
		)
		
		; Moving all the player-specific stuff over due to lack of second board.
		(set! destcnt 0)
		(while (< destcnt 29)		; Player card counters - Skill, Quorum, Loyalty, Trauma. - ADD Trust.
			(gimp-layer-set-offsets (vector-ref mylayers (+ (p_getlayerpos "PlayerCardCntr") destcnt))  
				(- (car (gimp-drawable-offsets (vector-ref mylayers (+ (p_getlayerpos "PlayerCardCntr") destcnt)))) 360)
				(cadr (gimp-drawable-offsets (vector-ref mylayers (+ (p_getlayerpos "PlayerCardCntr") destcnt)))))
			(set! destcnt (++ destcnt))
		); while
		
		(set! destcnt 0)
		(while (< destcnt 9)	; Player tokens - Current, President, Quorum, Admiral, Nukex3, CAG - ADD Intermediary here.
			(gimp-layer-set-offsets (vector-ref mylayers (+ (p_getlayerpos "Current") destcnt))  
				(- (car (gimp-drawable-offsets (vector-ref mylayers (+ (p_getlayerpos "Current") destcnt)))) 360)
				(cadr (gimp-drawable-offsets (vector-ref mylayers (+ (p_getlayerpos "Current") destcnt)))))
			(set! destcnt (++ destcnt))
		); while
		
		(set! destcnt 0)
		(while (< destcnt 20)	; 2 CYLON markers, Agenda backs, SYMPATHETIC, 3 Super Crisis markers and counts, and Assignments. - ADD Cylon powers here.
			(gimp-layer-set-offsets (vector-ref mylayers (+ (p_getlayerpos "Cylon") destcnt))  
				(- (car (gimp-drawable-offsets (vector-ref mylayers (+ (p_getlayerpos "Cylon") destcnt)))) 360)
				(cadr (gimp-drawable-offsets (vector-ref mylayers (+ (p_getlayerpos "Cylon") destcnt)))))
			(set! destcnt (++ destcnt))
		); while
		
		(set! destcnt 0)
		(while (< destcnt 79)	; Large amount of layers - Skill, Loyalty, Trauma backs, OPG markers, character cards. - ADD MUTINY, BALTARNATE MIRACLES, Trust HERE
			(gimp-layer-set-offsets (vector-ref mylayers (+ (p_getlayerpos "SkillCard") destcnt))  
				(- (car (gimp-drawable-offsets (vector-ref mylayers (+ (p_getlayerpos "SkillCard") destcnt)))) 360)
				(cadr (gimp-drawable-offsets (vector-ref mylayers (+ (p_getlayerpos "SkillCard") destcnt)))))
			(set! destcnt (++ destcnt))
		); while
		
		;shrink right border
		;(if (or useExo useDB)
			(gimp-image-resize image (- (car (gimp-image-width image)) 360) (car  (gimp-image-height image)) 0 0)
		;	(gimp-image-resize image (- (car (gimp-image-width image)) 410) (car  (gimp-image-height image)) 0 0) 
		;)
	); when Base + Kobol/IN

; 2 - Main Game Board and either 2 or fewer small (Peg, NC, Demetrius, RBB, Colony) boards or the CFB. If it's the CFB, we'll need to move it down.
	(when (and usePeg (not useCF) (not (or (string=? objective "New Caprica") (string=? objective "Earth") (string=? objective "Ionian Earth") (string=? objective "Colony"))))
(logit "ConfigureBoard  2 - MGB and Pegasus board")
		
	); when Pegasus & Kobol/IN
	
	
; 3 - Pegasus & NC (same board as 2, but NC is visible?)
	(when (and usePeg (not useCF) (string=? objective "New Caprica"))
(logit "ConfigureBoard 3 - MGB, Pegasus, and New Caprica boards")

	);when Pegasus & NC

; 4 - Base & CF & Kobol/IN
	(when (and (not usePeg) useCF (not (or (string=? objective "New Caprica") (string=? objective "Earth") (string=? objective "Ionian Earth"))))
(logit "ConfigureBoard 4 - Base & CF & Kobol/IN")
		; move the Cylon Fleet down
		(gimp-layer-set-offsets (vector-ref mylayers (p_getlayerpos "CylonFleet"))  
			(car (gimp-drawable-offsets (vector-ref mylayers (p_getlayerpos "CylonFleet"))))
			(+ (cadr (gimp-drawable-offsets (vector-ref mylayers (p_getlayerpos "CylonFleet")))) 480))

		(set! destcnt 0)
		(while (< destcnt 4)
			(gimp-layer-set-offsets (vector-ref mylayers (+ (p_getlayerpos "PursuitTrack") destcnt))  
				(car (gimp-drawable-offsets (vector-ref mylayers (+ (p_getlayerpos "PursuitTrack") destcnt))))
				(+ (cadr (gimp-drawable-offsets (vector-ref mylayers (+ (p_getlayerpos "PursuitTrack") destcnt)))) 480))
			(set! destcnt (++ destcnt))
		)
	);when Base & CF & Kobol/IN
	
; 5 - Pegasus & CF & Kobol/IN
	(when (and usePeg useCF (not (or (string=? objective "New Caprica") (string=? objective "Earth") (string=? objective "Ionian Earth") (string=? objective "Colony")))) ; Add a check against CCW here as well. This is strictly Peg + CFB, nothing else.
(logit "ConfigureBoard 5 - MGB, Pegasus, and Cylon Fleet boards")
		; Need a left border - extend the image width by 250, justify all the existing data to the right
		(gimp-image-resize image (+ (car (gimp-image-width image)) 250) (car  (gimp-image-height image)) 250 0)
	
		; Move Objective, Distance information.
		(while (< destcnt 34)
			(gimp-layer-set-offsets (vector-ref mylayers (+ (p_getlayerpos "FinalDest") destcnt)) 50
				(cadr (gimp-drawable-offsets (vector-ref mylayers (+ (p_getlayerpos "FinalDest") destcnt))))) ; Move Kobol and then next 27 layers over to the right-hand border.
			(set! destcnt (++ destcnt))
		); while
		(gimp-layer-set-offsets (vector-ref mylayers (p_getlayerpos "Distance")) 80			; Move the Distance counter
			(cadr (gimp-drawable-offsets (vector-ref mylayers (p_getlayerpos "Distance")))))
			
		; Crisis
		(gimp-layer-set-offsets (vector-ref mylayers (p_getlayerpos "CrisisToken")) 50 1360)
		(gimp-layer-set-offsets (vector-ref mylayers (p_getlayerpos "CrisisCntr")) 50 1480)
		
		; Supers
		(gimp-layer-set-offsets (vector-ref mylayers (+ (p_getlayerpos "CrisisToken") 3)) 50 1130)
		(gimp-layer-set-offsets (vector-ref mylayers (+ (p_getlayerpos "CrisisCntr") 4)) 50 1250)
		
		; Quorum
		(gimp-layer-set-offsets (vector-ref mylayers (+ (p_getlayerpos "CrisisToken") 2)) 50 900)
		(gimp-layer-set-offsets (vector-ref mylayers (+ (p_getlayerpos "CrisisCntr") 2)) 50 1020)

		; Mutiny
		(gimp-layer-set-offsets (vector-ref mylayers (+ (p_getlayerpos "CrisisToken") 5)) 50 670)
		(gimp-layer-set-offsets (vector-ref mylayers (+ (p_getlayerpos "CrisisCntr") 5)) 50 790)		
	);  when Peg & CF & Kobol/IN
	
; 6 - Pegasus & CF & NC
	(when (and usePeg useCF (string=? objective "New Caprica"))
(logit "ConfigureBoard 6 - MGB, Pegasus, Cylon Fleet, and New Caprica boards.")
		; Uses Cylon Fleet with a New Caprica Destination

		; Needs a 
		(gimp-image-resize image (+ (car (gimp-image-width image)) 790) (car  (gimp-image-height image)) 790 0)
		; move the Cylon Fleet and its filter
		(gimp-layer-set-offsets (vector-ref mylayers (p_getlayerpos "CylonFleet")) 0 776)
		(gimp-layer-set-offsets (vector-ref mylayers (+ (p_getlayerpos "Filter") 4)) 0 776)
		
		(set! destcnt 0)
		(while (< destcnt 4)
			(gimp-layer-set-offsets (vector-ref mylayers (+ (p_getlayerpos "PursuitTrack") destcnt)) (+ 275 (* destcnt 54)) 820)
			(set! destcnt (++ destcnt))
		)
		;move the graveyard and resize it
		(gimp-layer-scale (vector-ref mylayers (p_getlayerpos "Graveyard")) 748 500 FALSE)
		(gimp-layer-set-offsets (vector-ref mylayers (p_getlayerpos "Graveyard")) 21 230)
		
		(let*
			(
				(iter 0)
				(baselayer (p_getlayerpos "DamagedCivs"))
		)
			(while (< iter 8)
				(gimp-layer-translate (vector-ref mylayers (+ baselayer iter)) -2550 350)
				(set! iter (++ iter))
			)
		)

;	(logit "ConfigureBoard 6 - Base & CF & New Caprica")
;
;	; Move Objective, Distance information.
;	(while (< destcnt 34)
;		(gimp-layer-translate (vector-ref mylayers (+ (p_getlayerpos "FinalDest") destcnt)) 0 60) ; Move New Caprica Card and destinations a little down
;		(set! destcnt (++ destcnt))
;	); while
;	(gimp-layer-translate (vector-ref mylayers (p_getlayerpos "Distance")) 0 60)			; Also move the Distance counter 
;	
;	; "Turn" will go to the left
;	(gimp-layer-translate (vector-ref mylayers (p_getlayerpos "Turn")) -170 0)
;	
;	; Move Civilian and Counter below the distance
;	(gimp-layer-translate (vector-ref mylayers (p_getlayerpos "CivCntr")) 170 365)
;	(gimp-layer-translate (vector-ref mylayers (p_getlayerpos "CivToken")) 170 365)
;	
;	; Move all decks down
;	; Crisis
;	(gimp-layer-translate (vector-ref mylayers (p_getlayerpos "CrisisToken")) -50 400)
;	(gimp-layer-translate (vector-ref mylayers (p_getlayerpos "CrisisCntr")) -50 400)
;
;	; Supers
;	(gimp-layer-translate (vector-ref mylayers (+ (p_getlayerpos "CrisisToken") 3)) -50 400)
;	(gimp-layer-translate (vector-ref mylayers (+ (p_getlayerpos "CrisisCntr") 4)) -50 400)
;
;	; Quorum
;	(gimp-layer-translate (vector-ref mylayers (+ (p_getlayerpos "CrisisToken") 2)) -50 400)
;	(gimp-layer-translate (vector-ref mylayers (+ (p_getlayerpos "CrisisCntr") 2)) -50 400)
;
;	; Mutiny
;	(gimp-layer-translate (vector-ref mylayers (+ (p_getlayerpos "CrisisToken") 5)) -50 400)
;	(gimp-layer-translate (vector-ref mylayers (+ (p_getlayerpos "CrisisCntr") 5)) -50 400)		
;	
;	;move the graveyard and resize it
;	(gimp-layer-scale (vector-ref mylayers (p_getlayerpos "Graveyard")) 600 400 FALSE)
;	(gimp-layer-translate (vector-ref mylayers (p_getlayerpos "Graveyard")) -950 0)
;	(set! destcnt 0)
;	(while (< destcnt 8)
;		(gimp-layer-translate (vector-ref mylayers (+ (p_getlayerpos "DamagedCivs") destcnt)) -80 50)
;		(set! destcnt (++ destcnt))
;	)
;
;	; We expand the image by 465 pixels south - that's where we'll place the new boards
;	(gimp-image-resize image (car (gimp-image-width image)) (+ (car  (gimp-image-height image)) 465) 0 0)
;
;	; move New Caprica and Pegasus boards
;	(gimp-layer-set-offsets (vector-ref mylayers (p_getlayerpos "Pegasus")) 0 1560)
;	(gimp-layer-set-offsets (vector-ref mylayers (p_getlayerpos "NewCaprica")) 785 1560)
;	(gimp-layer-set-offsets (vector-ref mylayers (+ (p_getlayerpos "Filter") 4)) 785 1560)
;
;	; Spacing all the player-specific stuff
;	(let* 
;		(
;			(category (list->vector '("PlayerCardCntr" "LoyaltyCntr" "TraumaCntr" "MutinyCntr" "SkillCard" "LoyaltyCard" "Trauma" "Mutiny" "1PG")))
;			(auxcnt nil)
;		)
;		(set! auxcnt 0)
;		(while (< auxcnt (vector-length category))
;			(set! destcnt 0)
;			(while (< destcnt 7)
;				(gimp-layer-set-offsets (vector-ref mylayers (+ (p_getlayerpos (vector-ref category auxcnt)) destcnt))  
;					(car (gimp-drawable-offsets (vector-ref mylayers (+ (p_getlayerpos (vector-ref category auxcnt)) destcnt))))
;					(+ (cadr (gimp-drawable-offsets (vector-ref mylayers (+ (p_getlayerpos (vector-ref category auxcnt)) destcnt)))) (* destcnt 70)))
;				(set! destcnt (++ destcnt))
;			); while
;			(set! auxcnt (++ auxcnt))
;		); while
;	); let
;
;	; Why are there only 3 blank cards?
;	(set! destcnt 0)
;	(while (< destcnt 3)		; Player card counters - Skill
;		(gimp-layer-set-offsets (vector-ref mylayers (+ (p_getlayerpos "BlankCard5") destcnt))  
;			(car (gimp-drawable-offsets (vector-ref mylayers (+ (p_getlayerpos "BlankCard5") destcnt))))
;			(+ (cadr (gimp-drawable-offsets (vector-ref mylayers (+ (p_getlayerpos "BlankCard5") destcnt)))) (* destcnt 70) 280))
;		(set! destcnt (++ destcnt))
;	); while
;
;	; We'll use a different cardoffset (character sheets) here
;	(set! cardoffsetY (+ 70 cardoffsetY))
;
;	; move the Cylon Fleet
;	(gimp-layer-translate (vector-ref mylayers (p_getlayerpos "CylonFleet")) 0 945)
;	(set! destcnt 0)
;	(while (< destcnt 4)
;		(gimp-layer-translate (vector-ref mylayers (+ (p_getlayerpos "PursuitTrack") destcnt)) 0 945)
;		(set! destcnt (++ destcnt))
;	)
;
;	; move all the skill decks to the left (245 pixels)
;	(set! destcnt 0)
;	(while (< destcnt 7)
;		(gimp-layer-translate (vector-ref mylayers (+ (p_getlayerpos "PoliticsDeck") destcnt)) -245 0)
;		(gimp-layer-translate (vector-ref mylayers (+ (p_getlayerpos "PoliticsCntr") destcnt)) -245 0)
;		(set! destcnt (++ destcnt))
;	)
;	; move the Logo
;	(gimp-layer-translate (vector-ref mylayers (p_getlayerpos "Logo")) 1200 -950)

);when Peg & CF & New Caprica

; 7 - Base & Earth
	(when (and (not usePeg) (not useCF) (or (string=? objective "Earth") (string=? objective "Ionian Earth")))
		(logit "ConfigureBoard 7 - Base & Earth")
		
		; Move Objective, Distance information.
		(while (< destcnt 34)
			(gimp-layer-translate (vector-ref mylayers (+ (p_getlayerpos "FinalDest") destcnt)) 0 60) ; Move Earth Card and destinations a little down
			(set! destcnt (++ destcnt))
		); while
		(gimp-layer-translate (vector-ref mylayers (p_getlayerpos "Distance")) 0 60)			; Also move the Distance counter 
		
		; "Turn" will go to the left
		(gimp-layer-translate (vector-ref mylayers (p_getlayerpos "Turn")) -170 0)
		
		; Move Civilian and Counter below the distance
		(gimp-layer-translate (vector-ref mylayers (p_getlayerpos "CivCntr")) -170 550)
		(gimp-layer-translate (vector-ref mylayers (p_getlayerpos "CivToken")) -170 550)
		
		; Move all decks down
		; Crisis
		(gimp-layer-translate (vector-ref mylayers (p_getlayerpos "CrisisToken")) 0 210)
		(gimp-layer-translate (vector-ref mylayers (p_getlayerpos "CrisisCntr")) 0 210)
	
		; Supers
		(gimp-layer-translate (vector-ref mylayers (+ (p_getlayerpos "CrisisToken") 3)) 0 210)
		(gimp-layer-translate (vector-ref mylayers (+ (p_getlayerpos "CrisisCntr") 4)) 0 210)
	
		; Quorum
		(gimp-layer-translate (vector-ref mylayers (+ (p_getlayerpos "CrisisToken") 2)) 0 210)
		(gimp-layer-translate (vector-ref mylayers (+ (p_getlayerpos "CrisisCntr") 2)) 0 210)

		; Mutiny
		(gimp-layer-translate (vector-ref mylayers (+ (p_getlayerpos "CrisisToken") 5)) 0 210)
		(gimp-layer-translate (vector-ref mylayers (+ (p_getlayerpos "CrisisCntr") 5)) 0 210)		
		
		;move the graveyard and resize it
		(gimp-layer-scale (vector-ref mylayers (p_getlayerpos "Graveyard")) 600 400 FALSE)
		(gimp-layer-translate (vector-ref mylayers (p_getlayerpos "Graveyard")) -950 0)
		(set! destcnt 0)
		(while (< destcnt 8)
			(gimp-layer-translate (vector-ref mylayers (+ (p_getlayerpos "DamagedCivs") destcnt)) -80 50)
			(set! destcnt (++ destcnt))
		)

		; move the Demetrius and Rebel Basestar down
		(gimp-layer-translate (vector-ref mylayers (p_getlayerpos "Demetrius")) 0 480)
		(gimp-layer-translate (vector-ref mylayers (p_getlayerpos "RebelBasestar")) 0 480)
		(gimp-layer-translate (vector-ref mylayers (p_getlayerpos "RebelBasestarToken")) 0 480) ; Humans
		(gimp-layer-translate (vector-ref mylayers (+ (p_getlayerpos "RebelBasestarToken") 1)) 0 480) ; Cylons
		(gimp-layer-translate (vector-ref mylayers (+ (p_getlayerpos "Filter") 5)) 0 480)
		(gimp-layer-set-offsets (vector-ref mylayers (+ (p_getlayerpos "CrisisCntr") 6))
			(+ (car (gimp-drawable-offsets (vector-ref mylayers (p_getlayerpos "Demetrius")))) 610)
			(+ (cadr (gimp-drawable-offsets (vector-ref mylayers (p_getlayerpos "Demetrius")))) 225))
		(gimp-layer-set-visible (vector-ref mylayers (+ (p_getlayerpos "CrisisToken") 8)) 0)

		; move all the skill decks to the left (245 pixels)
		(set! destcnt 0)
		(while (< destcnt 7)
			(gimp-layer-translate (vector-ref mylayers (+ (p_getlayerpos "PoliticsDeck") destcnt)) -275 0)
			(gimp-layer-translate (vector-ref mylayers (+ (p_getlayerpos "PoliticsCntr") destcnt)) -275 0)
			(set! destcnt (++ destcnt))
		)
		
		; move the Logo
		(gimp-layer-translate (vector-ref mylayers (p_getlayerpos "Logo")) 1200 -950)

	);when Base & Earth

; 8 - CF & Earth (Why would ANYONE play like this?!?)
	(when (and (not usePeg) useCF (or (string=? objective "Earth") (string=? objective "Ionian Earth")))
		(logit "ConfigureBoard 8 - Base & CF & Earth")

		; Move Objective, Distance information.
		(while (< destcnt 34)
			(gimp-layer-translate (vector-ref mylayers (+ (p_getlayerpos "FinalDest") destcnt)) 0 60) ; Move Earth Card and destinations a little down
			(set! destcnt (++ destcnt))
		); while
		(gimp-layer-translate (vector-ref mylayers (p_getlayerpos "Distance")) 0 60)			; Also move the Distance counter 
		
		; "Turn" will go to the left
		(gimp-layer-translate (vector-ref mylayers (p_getlayerpos "Turn")) -170 0)
		
		; Move Civilian and Counter below the distance
		(gimp-layer-translate (vector-ref mylayers (p_getlayerpos "CivCntr")) 170 365)
		(gimp-layer-translate (vector-ref mylayers (p_getlayerpos "CivToken")) 170 365)
		
		; Move all decks down
		; Crisis
		(gimp-layer-translate (vector-ref mylayers (p_getlayerpos "CrisisToken")) 0 400)
		(gimp-layer-translate (vector-ref mylayers (p_getlayerpos "CrisisCntr")) 0 400)
	
		; Supers
		(gimp-layer-translate (vector-ref mylayers (+ (p_getlayerpos "CrisisToken") 3)) 0 400)
		(gimp-layer-translate (vector-ref mylayers (+ (p_getlayerpos "CrisisCntr") 4)) 0 400)
	
		; Quorum
		(gimp-layer-translate (vector-ref mylayers (+ (p_getlayerpos "CrisisToken") 2)) 0 400)
		(gimp-layer-translate (vector-ref mylayers (+ (p_getlayerpos "CrisisCntr") 2)) 0 400)

		; Mutiny
		(gimp-layer-translate (vector-ref mylayers (+ (p_getlayerpos "CrisisToken") 5)) 0 400)
		(gimp-layer-translate (vector-ref mylayers (+ (p_getlayerpos "CrisisCntr") 5)) 0 400)		
		
		; Missions
		(gimp-layer-translate (vector-ref mylayers (+ (p_getlayerpos "CrisisToken") 8)) 0 400)
		(gimp-layer-translate (vector-ref mylayers (+ (p_getlayerpos "CrisisCntr") 6)) 0 400)		

		;move the graveyard and resize it
		(gimp-layer-scale (vector-ref mylayers (p_getlayerpos "Graveyard")) 600 400 FALSE)
		(gimp-layer-translate (vector-ref mylayers (p_getlayerpos "Graveyard")) -950 0)
		(set! destcnt 0)
		(while (< destcnt 8)
			(gimp-layer-translate (vector-ref mylayers (+ (p_getlayerpos "DamagedCivs") destcnt)) -80 50)
			(set! destcnt (++ destcnt))
		)

		; We expand the image by almost 400 pixels south - that's where we'll place the new boards
		(gimp-image-resize image (car (gimp-image-width image)) (+ (car  (gimp-image-height image)) 390) 0 0)

		; move the Demetrius and Rebel Basestar down
		(gimp-layer-set-offsets (vector-ref mylayers (p_getlayerpos "Demetrius")) 0 1560)
		(gimp-layer-set-offsets (vector-ref mylayers (p_getlayerpos "RebelBasestar")) 785 1560)
		(gimp-layer-set-offsets (vector-ref mylayers (p_getlayerpos "RebelBasestarToken")) 1458 1605) ; Humans
		(gimp-layer-set-offsets (vector-ref mylayers (+ (p_getlayerpos "RebelBasestarToken") 1)) 1458 1605) ; Cylons
		(gimp-layer-set-offsets (vector-ref mylayers (+ (p_getlayerpos "Filter") 5)) 785 1560)
		(gimp-layer-set-visible (vector-ref mylayers (+ (p_getlayerpos "CrisisToken") 8)) 1)
	
		; Spacing all the player-specific stuff
		(let* 
			(
				(category (list->vector '("PlayerCardCntr" "LoyaltyCntr" "TraumaCntr" "MutinyCntr" "SkillCard" "LoyaltyCard" "Trauma" "Mutiny" "1PG")))
				(auxcnt nil)
			)
			(set! auxcnt 0)
			(while (< auxcnt (vector-length category))
				(set! destcnt 0)
				(while (< destcnt 7)
					(gimp-layer-set-offsets (vector-ref mylayers (+ (p_getlayerpos (vector-ref category auxcnt)) destcnt))  
						(car (gimp-drawable-offsets (vector-ref mylayers (+ (p_getlayerpos (vector-ref category auxcnt)) destcnt))))
						(+ (cadr (gimp-drawable-offsets (vector-ref mylayers (+ (p_getlayerpos (vector-ref category auxcnt)) destcnt)))) (* destcnt 60)))
					(set! destcnt (++ destcnt))
				); while
				(set! auxcnt (++ auxcnt))
			); while
		); let

		; Why are there only 3 blank cards?
		(set! destcnt 0)
		(while (< destcnt 3)		; Player card counters - Skill
			(gimp-layer-set-offsets (vector-ref mylayers (+ (p_getlayerpos "BlankCard5") destcnt))  
				(car (gimp-drawable-offsets (vector-ref mylayers (+ (p_getlayerpos "BlankCard5") destcnt))))
				(+ (cadr (gimp-drawable-offsets (vector-ref mylayers (+ (p_getlayerpos "BlankCard5") destcnt)))) (* destcnt 60) 240))
			(set! destcnt (++ destcnt))
		); while

		; We'll use a different cardoffset (character sheets) here
		(set! cardoffsetY (+ 60 cardoffsetY))

		; move the Cylon Fleet
		(gimp-layer-translate (vector-ref mylayers (p_getlayerpos "CylonFleet")) 0 870)
		(set! destcnt 0)
		(while (< destcnt 4)
			(gimp-layer-translate (vector-ref mylayers (+ (p_getlayerpos "PursuitTrack") destcnt)) 0 870)
			(set! destcnt (++ destcnt))
		)
	
		; move all the skill decks to the left (245 pixels)
		(set! destcnt 0)
		(while (< destcnt 7)
			(gimp-layer-translate (vector-ref mylayers (+ (p_getlayerpos "PoliticsDeck") destcnt)) -245 0)
			(gimp-layer-translate (vector-ref mylayers (+ (p_getlayerpos "PoliticsCntr") destcnt)) -245 0)
			(set! destcnt (++ destcnt))
		)
		; move the Logo
		(gimp-layer-translate (vector-ref mylayers (p_getlayerpos "Logo")) 1200 -950)
	
	);  when CF & Earth

; 9 - Pegasus & Earth
	(when (and usePeg (not useCF) (or (string=? objective "Earth") (string=? objective "Ionian Earth"))) ; Used only for Pegasus and Earth, without CF
		(logit "ConfigureBoard 9 - Base, Pegasus & Earth")
		; Need a left border - extend the image width by 250, justify all the existing data to the right
		(gimp-image-resize image (+ (car (gimp-image-width image)) 250) (car  (gimp-image-height image)) 250 0)

		; "Turn" will go to the left
		(gimp-layer-translate (vector-ref mylayers (p_getlayerpos "Turn")) -90 0)
		
		; Move Civilian and Counter below the distance
		(gimp-layer-translate (vector-ref mylayers (p_getlayerpos "CivCntr")) -90 0)
		(gimp-layer-translate (vector-ref mylayers (p_getlayerpos "CivToken")) -90 0)

		; Move Objective, Distance information.
		(while (< destcnt 34)
			(gimp-layer-set-offsets (vector-ref mylayers (+ (p_getlayerpos "FinalDest") destcnt)) 50 
				(cadr (gimp-drawable-offsets (vector-ref mylayers (+ (p_getlayerpos "FinalDest") destcnt))))) ; Move Kobol and then next 27 layers over to the right-hand border.
			(set! destcnt (++ destcnt))
		); while
		(gimp-layer-set-offsets (vector-ref mylayers (p_getlayerpos "Distance")) 80			; Move the Distance counter
			(cadr (gimp-drawable-offsets (vector-ref mylayers (p_getlayerpos "Distance")))))
		
		; Crisis
		(gimp-layer-set-offsets (vector-ref mylayers (p_getlayerpos "CrisisToken")) 50 1360)
		(gimp-layer-set-offsets (vector-ref mylayers (p_getlayerpos "CrisisCntr")) 50 1480)
	
		; Supers
		(gimp-layer-set-offsets (vector-ref mylayers (+ (p_getlayerpos "CrisisToken") 3)) 50 1130)
		(gimp-layer-set-offsets (vector-ref mylayers (+ (p_getlayerpos "CrisisCntr") 4)) 50 1250)
	
		; Quorum
		(gimp-layer-set-offsets (vector-ref mylayers (+ (p_getlayerpos "CrisisToken") 2)) 50 900)
		(gimp-layer-set-offsets (vector-ref mylayers (+ (p_getlayerpos "CrisisCntr") 2)) 50 1020)

		; Mutiny
		(gimp-layer-set-offsets (vector-ref mylayers (+ (p_getlayerpos "CrisisToken") 5)) 50 670)
		(gimp-layer-set-offsets (vector-ref mylayers (+ (p_getlayerpos "CrisisCntr") 5)) 50 790)		

		(gimp-layer-set-visible (vector-ref mylayers (+ (p_getlayerpos "CrisisToken") 8)) 0)
		(gimp-layer-set-offsets (vector-ref mylayers (+ (p_getlayerpos "CrisisCntr") 6))
			(+ (car (gimp-drawable-offsets (vector-ref mylayers (p_getlayerpos "Demetrius")))) 610)
			(+ (cadr (gimp-drawable-offsets (vector-ref mylayers (p_getlayerpos "Demetrius")))) 225))

	);  when Peg & Earth

; 10 - Pegasus & CF & Earth (The whole deal)
	(when (and usePeg useCF (or (string=? objective "Earth") (string=? objective "Ionian Earth")))
		(logit "ConfigureBoard 10 - Base & Pegasus & CF & Earth")

		; Need a left border - extend the image width by 250, justify all the existing data to the right
		(gimp-image-resize image (car (gimp-image-width image)) (+ (car  (gimp-image-height image)) 390) 0 0)

		; Move all decks down
		; Crisis
		(gimp-layer-translate (vector-ref mylayers (p_getlayerpos "CrisisToken")) 0 100)
		(gimp-layer-translate (vector-ref mylayers (p_getlayerpos "CrisisCntr")) 0 100)
	
		; Supers
		(gimp-layer-translate (vector-ref mylayers (+ (p_getlayerpos "CrisisToken") 3)) 0 100)
		(gimp-layer-translate (vector-ref mylayers (+ (p_getlayerpos "CrisisCntr") 4)) 0 100)
	
		; Quorum
		(gimp-layer-translate (vector-ref mylayers (+ (p_getlayerpos "CrisisToken") 2)) 0 100)
		(gimp-layer-translate (vector-ref mylayers (+ (p_getlayerpos "CrisisCntr") 2)) 0 100)

		; Mutiny
		(gimp-layer-translate (vector-ref mylayers (+ (p_getlayerpos "CrisisToken") 5)) 0 100)
		(gimp-layer-translate (vector-ref mylayers (+ (p_getlayerpos "CrisisCntr") 5)) 0 100)		
		
		; move the Demetrius and Rebel Basestar down
		(gimp-layer-set-offsets (vector-ref mylayers (p_getlayerpos "Demetrius")) 0 1560)
		(gimp-layer-set-offsets (vector-ref mylayers (p_getlayerpos "RebelBasestar")) 785 1560)
		(gimp-layer-set-offsets (vector-ref mylayers (p_getlayerpos "RebelBasestarToken")) 1458 1605) ; Humans
		(gimp-layer-set-offsets (vector-ref mylayers (+ (p_getlayerpos "RebelBasestarToken") 1)) 1458 1605) ; Cylons
		(gimp-layer-set-offsets (vector-ref mylayers (+ (p_getlayerpos "Filter") 5)) 785 1560)
		(gimp-layer-set-offsets (vector-ref mylayers (+ (p_getlayerpos "CrisisCntr") 6)) 615 1785)
		(gimp-layer-set-visible (vector-ref mylayers (+ (p_getlayerpos "CrisisToken") 8)) 0)
		
		; Spacing all the player-specific stuff
		(let* 
			(
				(category (list->vector '("PlayerCardCntr" "LoyaltyCntr" "TraumaCntr" "MutinyCntr" "SkillCard" "LoyaltyCard" "Trauma" "Mutiny" "1PG")))
				(auxcnt nil)
			)
			(set! auxcnt 0)
			(while (< auxcnt (vector-length category))
				(set! destcnt 0)
				(while (< destcnt 7)
					(gimp-layer-set-offsets (vector-ref mylayers (+ (p_getlayerpos (vector-ref category auxcnt)) destcnt))  
						(car (gimp-drawable-offsets (vector-ref mylayers (+ (p_getlayerpos (vector-ref category auxcnt)) destcnt))))
						(+ (cadr (gimp-drawable-offsets (vector-ref mylayers (+ (p_getlayerpos (vector-ref category auxcnt)) destcnt)))) (* destcnt 60)))
					(set! destcnt (++ destcnt))
				); while
				(set! auxcnt (++ auxcnt))
			); while
		); let

		; Why are there only 3 blank cards?
		(set! destcnt 0)
		(while (< destcnt 3)		; Player card counters - Skill
			(gimp-layer-set-offsets (vector-ref mylayers (+ (p_getlayerpos "BlankCard5") destcnt))  
				(car (gimp-drawable-offsets (vector-ref mylayers (+ (p_getlayerpos "BlankCard5") destcnt))))
				(+ (cadr (gimp-drawable-offsets (vector-ref mylayers (+ (p_getlayerpos "BlankCard5") destcnt)))) (* destcnt 60) 240))
			(set! destcnt (++ destcnt))
		); while

		; We'll use a different cardoffset (character sheets) here
		(set! cardoffsetY (+ 60 cardoffsetY))

		; move the Cylon Fleet
		(gimp-layer-translate (vector-ref mylayers (p_getlayerpos "CylonFleet")) 0 400)
		(set! destcnt 0)
		(while (< destcnt 4)
			(gimp-layer-translate (vector-ref mylayers (+ (p_getlayerpos "PursuitTrack") destcnt)) 0 400)
			(set! destcnt (++ destcnt))
		)

		; move the Pegasus board, its overlay and its damage tokens
		(gimp-layer-translate (vector-ref mylayers (p_getlayerpos "Pegasus")) 0 400)
		(gimp-layer-translate (vector-ref mylayers (p_getlayerpos "PegasusDestroyed")) 0 400)
		(gimp-layer-translate (vector-ref mylayers (+ (p_getlayerpos "DamageToken") 6)) 0 400)
		(gimp-layer-translate (vector-ref mylayers (+ (p_getlayerpos "DamageToken") 7)) 0 400)
		(gimp-layer-translate (vector-ref mylayers (+ (p_getlayerpos "DamageToken") 8)) 0 400)
		(gimp-layer-translate (vector-ref mylayers (+ (p_getlayerpos "DamageToken") 9)) 0 400)

		; move all the skill decks to the left (245 pixels)
		(set! destcnt 0)
		(while (< destcnt 7)
			(gimp-layer-translate (vector-ref mylayers (+ (p_getlayerpos "PoliticsDeck") destcnt)) -275 0)
			(gimp-layer-translate (vector-ref mylayers (+ (p_getlayerpos "PoliticsCntr") destcnt)) -275 0)
			(set! destcnt (++ destcnt))
		)
		; move the Logo
		(gimp-layer-translate (vector-ref mylayers (p_getlayerpos "Logo")) 1200 -950)
		
	);  when Peg & CF & Earth
	
	
	cardoffsetY      ; Because some configurations might want to use a different Y offset
); let
); define


(define (bsgp-BGColor myvalues)
	(if (= (length myvalues) 3)   ; Old-style CSV
		(gimp-context-set-foreground myvalues)
		(begin    ; else
			(gimp-context-set-foreground (cdr myvalues))
			(if (string=? (car myvalues) "Match")		; Filters have to match the background color
				(begin
					(gimp-drawable-fill (vector-ref mylayers (p_getlayerpos "Filter")) 0)
					(gimp-drawable-fill (vector-ref mylayers (+ (p_getlayerpos "Filter") 1)) 0)
					(gimp-drawable-fill (vector-ref mylayers (+ (p_getlayerpos "Filter") 2)) 0)
					(gimp-drawable-fill (vector-ref mylayers (+ (p_getlayerpos "Filter") 3)) 0)
					(gimp-drawable-fill (vector-ref mylayers (+ (p_getlayerpos "Filter") 4)) 0)
					(gimp-drawable-fill (vector-ref mylayers (+ (p_getlayerpos "Filter") 5)) 0)
				)
			)
		)
	) ; if
	(gimp-drawable-fill (vector-ref mylayers (p_getlayerpos "Borders")) 0)
	(gimp-drawable-fill (vector-ref mylayers (+ (p_getlayerpos "Borders") 1)) 0)
	(gimp-drawable-fill (vector-ref mylayers (+ (p_getlayerpos "Borders") 2)) 0)
); define

;
(define (bsgp-Phase myvalues useCF)
; we should only be calling this for New Caprica games
; GamePhase values:
;1) Early game...Show NC Filter, show Crisis deck & count, hide NC crisis & cnt, Show CivCnt, hide Prepared & Locked
;2) ON NC...Show Galactica, Pegasus, Colonial One filters, hide Crisis & cnt, show NC Crisis & cnt, Hide CivToken &  CivCnt, show Prepared & Locked
;3) end game...Show Colonial One filter, hide Crisis & cnt, show NC Crisis & cnt, Hide CivCnt, show Prepared & Locked
;4) For Non-NC games.  Same as (1), but hide the New Caprica layer as well.
(let*
	(
;		showflags order: GalFilter, C1Filter, PegFil, NCFil, CFFil, CrisisDeck, OffboardCiv
		(showflags #( () (0 0 0 1 0 1 1 1) (1 1 1 0 1 0 0 1) (0 1 0 0 0 0 0 1) (0 0 0 1 0 1 1 0)))
		(myflags nil)
		(curflag nil)
		(notflag nil)
		(crisiscntrpos (p_getlayerpos "CrisisCntr"))
		(crisistokenpos (p_getlayerpos "CrisisToken"))
		(tmplayer nil)
	)
	
	(set! myflags (vector-ref showflags (car myvalues)))
	; flip the filters
	(gimp-drawable-set-visible (vector-ref mylayers (p_getlayerpos "Filter")) (car myflags))
	(gimp-drawable-set-visible (vector-ref mylayers (+ (p_getlayerpos "Filter") 1)) (cadr myflags))
	(gimp-drawable-set-visible (vector-ref mylayers (+ (p_getlayerpos "Filter") 2)) (caddr myflags))
	(gimp-drawable-set-visible (vector-ref mylayers (+ (p_getlayerpos "Filter") 3)) (cadddr myflags))
	(gimp-drawable-set-visible (vector-ref mylayers (+ (p_getlayerpos "Filter") 4)) (btoint (and useCF (car (cddddr myflags)))))

	; next is crisis decks
	(set! myflags (cdr (cddddr myflags)))
	(set! curflag (car myflags))
	(if (= curflag 1) (set! notflag 0) (set! notflag 1))
	(gimp-drawable-set-visible (vector-ref mylayers (p_getlayerpos "CrisisCntr")) curflag)
	(gimp-drawable-set-visible (vector-ref mylayers (p_getlayerpos "CrisisToken")) curflag)
	(gimp-drawable-set-visible (vector-ref mylayers (+ (p_getlayerpos "CrisisCntr") 1)) notflag)
	(gimp-drawable-set-visible (vector-ref mylayers (+ (p_getlayerpos "CrisisToken") 1)) notflag)
	; final the civilian ships	
	(set! curflag (cadr myflags))
	(if (= curflag 1) (set! notflag 0) (set! notflag 1))
	(gimp-drawable-set-visible (vector-ref mylayers (p_getlayerpos "CivCntr")) curflag)
	(gimp-drawable-set-visible (vector-ref mylayers (p_getlayerpos "CivToken")) curflag)
	(gimp-drawable-set-visible (vector-ref mylayers (+ (p_getlayerpos "CivCntr") 1)) notflag)
	(gimp-drawable-set-visible (vector-ref mylayers (+ (p_getlayerpos "CivCntr") 2)) notflag)
	(gimp-drawable-set-visible (vector-ref mylayers (p_getlayerpos "NCCivToken")) notflag)
	(set! curflag (caddr myflags))
	;(gimp-drawable-set-visible (vector-ref mylayers (p_getlayerpos "NewCaprica")) curflag)
)
);	bsgp-Phase
;
(define (bsgp-Graveyard image myvalues)
(let*
	(
		(tokenpos (+ (p_getlayerpos "PlayerToken") playercount))
		(bodycnt nil)
		(bodyid 0)
		(tokenoffset nil)
		(playername nil)	
		(cntr nil)
		(offX 51)	;width of a player token
		(topoff 0) 
		(graveX nil)	
		(graveY nil)
		(graveWidth (car (gimp-drawable-width (vector-ref mylayers (p_getlayerpos "Graveyard")))))
		(graveHeight (car (gimp-drawable-height (vector-ref mylayers (p_getlayerpos "Graveyard")))))
	)
	(set! bodycnt (length myvalues))
	
	(when (> (* bodycnt offX) graveWidth) 
		(set! offX (quotient (* offX (quotient graveWidth offX)) bodycnt)) 
	)
	(set! topoff (* (-- bodycnt) 0.5 offX))
	
	(set! graveX (+ (car (gimp-drawable-offsets (vector-ref mylayers (p_getlayerpos "Graveyard"))))	(quotient graveWidth 2) -25))
	(set! graveY (+ (cadr (gimp-drawable-offsets (vector-ref mylayers (p_getlayerpos "Graveyard")))) (quotient graveHeight 5)))
	
	(while (not (null? myvalues))
		; get the name of the current player
		; find the token for the player and move it into the correct location
		;  also rearrange the tokens so the 2nd row layers are above the 1st row layers

		(set! bodyid (++ bodyid))
		
		(set! playername (car myvalues))
		(set! cntr 0)
		(while (< cntr (- 38 playercount))
			(when (string=5? playername (car (gimp-drawable-get-name (vector-ref mylayers (+ tokenpos cntr)))))
				(set! tokenoffset cntr)
				(set! cntr 38)
			) ;when
			(set! cntr (++ cntr))
		) ;while
		
		; so now I know where the token is relative to the start of the available tokens
		; now we need to make the token visible and move it to the graveyard
		(gimp-drawable-set-visible (vector-ref mylayers (+ tokenpos tokenoffset)) TRUE)
		(gimp-layer-scale (vector-ref mylayers (+ tokenpos tokenoffset)) 48 72 FALSE)
		(gimp-layer-set-offsets (vector-ref mylayers (+ tokenpos tokenoffset)) (- graveX topoff) graveY)
		(set! topoff (- topoff offX))
		
		(when (> bodycnt 4)
			(set! cntr tokenoffset)
			(while (> cntr 0)
				(gimp-image-raise-layer image (vector-ref mylayers (+ tokenpos tokenoffset)))
				(set! cntr (-- cntr))
			) ;while
    )  
    ;the layers are no longer in the same order as mylayers, so refresh it
		(set! mylayers (cadr (gimp-image-get-layers image)))
		(set! myvalues (cdr myvalues))
		
	) ;while 
) ;let
) ;bsgp-Graveyard
;

; leftover from when I was trying to fly in formation...seems a shame to waste it...<shrug>
;		(raiderloc #( ((190 650) (290 690) (390 730) (190 730) (290 770) (390 810)) 
;			((660 550) (760 590) (660 630) (860 550) (860 630) (760 510))
;			((980 550) (1080 590) (980 630) (1180 550) (1180 630) (1080 510))
;			((1460 730) (1550 690) (1640 650) (1640 730) (1550 770) (1460 810))
;			((980 1360) (1080 1400) (980 1440) (1180 1360) (1180 1440) (1080 1480))
;			((640 1360) (740 1400) (640 1440) (840 1360) (840 1440) (740 1480)))

;general note:
; there is an apparent bug in the parser that casues a problem if you have an input line with a symbol/number followed by a strings which have spaces.  Avoid that if possible.


;general comments and changelog
; 12/9/10 - fixed location/offset of turn layer from 270 to 271 (to support the Pegasus Destroyed layer)
;    - changee formatting of quorum cards in hand layer from 0 to 2
;    - added Phase 4 = No New Caprica to hide the new caprica layer
;    - added NewCaprica layer reference 
;    - boardspecial "Pegasus" is now enabled to show the pegasus destroyed layer

; 12/13/10 - fixed deploy locations of civilians in sector 1 so they aren't crossing into sector 6

; 12/21/10 - added bsgp-destination and the "destination" option to support variable  final destinations.

; 1/27/11 - added Exodus characters, tokens, & 3rd nuke
