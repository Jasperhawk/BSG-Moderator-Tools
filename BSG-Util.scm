; this returns the location in the order stack
(define (get-layer-by-name layname image)
(let*
	(		
		(laytmp nil)
		(layid nil)
	)
	(set! laytmp (cadr (gimp-image-get-layers image)))
	(set! layid 1)
	(while (not (>= layid (vector-length laytmp)))
		(when (string-ci=? layname (car (gimp-layer-get-name (vector-ref laytmp layid))))
			(display (string-append "Layer Location: " (number->string layid) "\n"))
			(display (string-append "Layer ID: " (number->string (vector-ref laytmp layid)) "\n"))
			(set! layid (vector-length laytmp))
		)
		(set! layid (++ layid))
	)
)
)

; srcid and destid are layerID's
(define (move-layer-to-layer srcid destid)
(let*
	(
		(dx nil)
		(dy nil)
	)
	(set! dx (- (car (gimp-drawable-offsets destid)) (car (gimp-drawable-offsets srcid))))
	(set! dy (- (cadr (gimp-drawable-offsets destid)) (cadr (gimp-drawable-offsets srcid))))
	(gimp-layer-translate srcid dx dy)
)
)

; utility functions
(define (++ srcval) (let* ()(+ srcval 1)))
(define (-- srcval) (let* ()(- srcval 1)))

; This reads either the next string, or the rest of the line as a scheme symbol
; This is to work around the changes to how the "read" builtin handles the " deliminator
; between tinyscheme 1.40 and 1.41, which breaks the assumptions in getcvsline and
; causes it to fail with gimp 2.10
(define (readstringorsymbol in)
(let*
   (
      (valuelst '())
      (templst '())
      (tempstr nil)
      (symbolstr nil)
      (nextitem nil)
   )
   (set! nextitem (read in))
   (if (and (symbol? (list-ref nextitem 1)) (not (char-ci=? (peek-char in) #\newline)))
      (begin
          ; We have a symbol, but we didn't read to the newline, so we have to create
          ; a symbol with the rest of the line
          (while (not (char-ci=? (peek-char in) #\newline))
             (set! templst (append templst (list (read-char in))))
          ) ; while
          (set! tempstr (list->string templst))
          (set! symbolstr (symbol->string (list-ref nextitem 1)))
          (set! symbolstr (string-append symbolstr tempstr))
          (set! valuelst (append valuelst (list (list-ref nextitem 0))))
          (set! valuelst (append valuelst (list (string->symbol symbolstr))))
      )
      (begin
         ; else we just return the read results
         (set! valuelst nextitem)
      )
  ) ; if
  (set! valuelst valuelst)
) ; let
) ; define


; Reading from the csv is a strange process.  Each line will start with a string.  The first string of the first line should have
; already been read when this is called.  each call of this reads everyhing after the first string and builds it in a list (A), then 
; reads the first string of the next line (B) and returns a list comprising ((A) (B)).
; so if the first two lines of the file are
;"Game","123","1.2"
;"Resources",8,8,10,12"
; The first item ("Game") should have already been read, then getcvsline is called, it will return
; (("123" "1.2") "Resources")

(define (getcsvline in)
(let*
	(
		(setname nil)
		(valuelst '())
		(nextitem nil)
		(myitem nil)
		(isnum nil)
		(endflag nil)
		(logflag FALSE)
		(havenexttok nil)
	)
	(set! nextitem (readstringorsymbol in))
	(set! valuelst '())
	(while (not (or (string? nextitem) (eof-object? nextitem)))
		(set! havenexttok FALSE)
		(set! nextitem (cadr nextitem))
		;this is to deal with lots of empty cells...
		(while (list? nextitem) (set! nextitem (cadr nextitem)) (set! havenexttok TRUE))
		
		(when (= havenexttok FALSE)
			(if (string? nextitem)
				(when (not (string=? nextitem "")) (set! valuelst (append valuelst (list nextitem))))
				(begin
					; this must be a symbol, like 8,8,10,12  which we will need to convert to a string and then convert into a list
					; there is a special case here, if the line was "SetName",<value> with only one value, then nextitem is a number, not a symbol
					(if (number? nextitem)
						(set! nextitem (string->list (number->string nextitem)))
						(set! nextitem (string->list (symbol->string nextitem)))
					)
					; so it's now (#\8 #\, #\8 #\, #\10 #\, #\12)
					(set! myitem "")
					(set! isnum FALSE)
					(set! endflag FALSE)
					(while (not (null? nextitem))
						(if (char=? #\, (car nextitem))
							(begin
								; we need to make sure the type is correct...
								(when (= isnum TRUE) (set! myitem (string->number myitem)))
								(when (or (number? myitem) (not (string=? myitem "")))
									(set! valuelst (append valuelst (list myitem)))
								)
								(set! myitem "")
								(set! isnum FALSE)
							)
							(begin
								(when (and (<= (char->integer (car nextitem)) (char->integer #\9))
										(>= (char->integer (car nextitem)) (char->integer #\0)))
									(set! isnum TRUE)
								)
								; strip the quotes, they'll be put back in automatically
								(when (not (char=? #\" (car nextitem)))
									(set! myitem (string-append myitem (string (car nextitem))))
								)
							)
						) ;if
						(set! nextitem (cdr nextitem))
					) ;while
					; catch the last item
					(when (= isnum TRUE) (set! myitem (string->number myitem)))
					(when (or (number? myitem) (not (string=? myitem "")))
						(set! valuelst (append valuelst (list myitem)))
					)
				) ;begin
			) ;if string?
			(set! nextitem (read in))
		) ;when (= havenexttok FALSE)
	) ;while
	;clean valuelst of any dummy records
	(list valuelst nextitem)
) ;let
) ;define

;  takes a fully qualified file name and splits it into (path filename extension)
; filename in this case contains the extension, the extension is just split off for simplicity of a check
(define (splitfullfname fullfname)
(let*
	(
		(fname nil)
		(ext nil)
		(delim nil)
	)
	(set! fullfname (reverse (string->list fullfname)))
	; this needs to parse for '/' if we're in unix or '\' in windows....
	(if (list? (member #\\ fullfname))
		(set! delim #\\)
		(set! delim #\/)
	)	; if
	(while (and (not (char=? (car fullfname) delim)) (not (null? fullfname)))
		(set! fname (append fname (list (car fullfname))))
		(set! fullfname (cdr fullfname))
	)
	(set! ext (list->string (reverse (list (car fname) (cadr fname) (caddr fname)))))
	(set! fname (list->string (reverse fname)))
	(set! fullfname (list->string (reverse fullfname)))
	(list fullfname fname ext)
) ;let
) ;define

; this does a case-insensitive string compare to a length of the shorter string, so 
; (string=5? "STRANDED" "Stranded on Caprica") is true
(define (string=5? str1 str2) 
(let* 
	(
		(cmpsz nil)
	)
	(set! cmpsz (min (string-length str1) (string-length str2)))
	(string-ci=? (substring str1 0 cmpsz) (substring str2 0 cmpsz))
) ;let
) ;define


; Globals used for logging
(define logfile nil)
(define logfname nil)


(define (initlog filepath)
	(when (port? logfile) (close-output-port logfile))
	(when (not (string=? filepath ""))
		(set! logfile (open-output-file (string-append filepath logfname)))
	)
) 

(define (logit strtolog)
	(when (port? logfile) (display strtolog logfile) (display "\n" logfile))) 
	
	

;

(define (outlineText layerID outSize bgclr)
(let*
	(
		(newlayerID nil)
		(imageID nil)
		(layerpos nil)
	)
	(set! newlayerID (car (gimp-layer-copy layerID TRUE)))
	(set! imageID (car (gimp-drawable-get-image layerID)) )
	(set! layerpos (car (gimp-image-get-layer-position imageID layerID)))
;(logit (string-append "layer: " (number->string layerID) " - newlayer: " (number->string newlayerID) " - image: " (number->string imageID) " - layerpos: " (number->string layerpos)))
	; if the layer is not visible, don't bother (and the merge won't work correctly)
	(when (= (car (gimp-drawable-get-visible (vector-ref mylayers layerpos))) TRUE)
		(gimp-image-add-layer imageID newlayerID layerpos)
		(gimp-selection-layer-alpha layerID)
		(gimp-selection-grow imageID outSize)
		(gimp-context-set-foreground bgclr)
		(gimp-edit-fill layerID 0)
		(gimp-image-merge-down imageID newlayerID 0)
		(gimp-selection-none imageID)
	)
); left
); outlineText
