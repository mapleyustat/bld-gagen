(in-package :bld-gagen)

(defun make-gaobj (sym class)
  "Make symbolic GA object of given symbol and specialized child class"
  (if (or (equal class 'float) (equal class 'integer) (equal class 'number))
      sym
      (let* ((tmp (make-instance class))
	     (ptmp (make-instance (parent tmp))))
	(loop for b across (bitmap tmp)
	   do (setf (gref ptmp b) `(gref ,sym ,b)))
	ptmp)))

(defun find-bitmap-test (bbl bitmap)
  "Test if a list of basis bitmaps is in a bitmap"
  (every #'(lambda (bb) (find bb bitmap)) bbl))

(defun non-zero-basis-bitmaps (g)
  "Given parent GA object, return a list of basis bitmaps corresponding to non-zero or symbolic coefficients"
  (loop for b across (bitmap g)
     for c across (coef g)
     unless (and (numberp c) (zerop c))
     collect b))

(defun find-specs (bbl spec)
  "Given a list of basis-bitmaps and an alist of specialized GA sub-classes & their bitmaps, return a list of the subclass names contain them"
  (loop for (name bitmap) in spec
     when (find-bitmap-test bbl bitmap)
     collect name))

(defun find-spec (g)
  "Given a parent GA object and hash-table of bitmaps, return the hash-table key with corresponding bitmap of minimum length that matched non-zero/symbolic coefficients of the GA object. This is the name of a specialized GA class."
  (with-slots (spec) g
    (loop for name in (find-specs (non-zero-basis-bitmaps g) spec)
       for namemin = name
       then (if (< (length (second (assoc name spec)))
		   (length (second (assoc namemin spec))))
		name
		namemin)
       finally (return namemin))))

(defun make-args (num)
  "Make argument symbols as 'g appended to number"
  (loop for n from 1 upto num
     collect (build-symbol g (:< n))))

(defmacro defgamethod (fun &rest classes)
  "Define a geometric algebra method given name of generic function and list of classes for each argument"
  (let* ((args (make-args (length classes)))
	 (gaobjs (mapcar #'make-gaobj args classes))
	 (res (apply fun gaobjs))
	 (resclass (when (typep res 'g)
		     (find-spec res)))
	 (reslist (when resclass
		    (loop for b across (bitmap (make-instance resclass))
		       collect (gref res b)))))
    `(defmethod ,fun (,@(mapcar #'list args classes))
       ,(if resclass
	    `(make-instance ',resclass :coef (vector ,@reslist))
	    res))))

(defmacro defgamethods1 (fun classes)
  `(progn
     ,@(loop for class in classes
	  collect `(defgamethod ,fun ,class))))

(defmacro defgamethods2 (fun classes1 classes2)
  `(progn
     ,@(loop for class1 in classes1
	  append (loop for class2 in classes2
		    collect `(defgamethod ,fun ,class1 ,class2)))))

(defmacro defgamethods3 (fun classes1 classes2 classes3)
  `(progn
     ,@(loop for class1 in classes1
	  append (loop for class2 in classes2
		    append (loop for class3 in classes3
			      collect `(defgamethod ,fun ,class1 ,class2 ,class3))))))

(defun spec-classes (class)
  (mapcar #'first (spec (make-instance class))))

(defun spec-bitmaps (class)
  (mapcar #'second (spec (make-instance class))))

(defmacro defgamethodsall1 (fun parent)
  `(defgamethods1 ,fun ,(spec-classes parent)))

(defmacro defgamethodsall2 (fun parent)
  (let ((classes (spec-classes parent)))
    `(defgamethods2 ,fun ,classes ,classes)))
