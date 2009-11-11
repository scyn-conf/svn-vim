" File: svn.vim
" Brief: svn integration plugin for vim
" Author: Scyn - Remi Chaintron <remi.chaintron@gmail.com>
" Url: http:/github.com/scyn-conf/svn-vim
"

"
" Function: s:SvnInitializeVariable () function {{{2
" This function is intended to provide variable initialization, only in the case
" the variable does not exist.
" Args:
" variable: a string containing the name of the variable to be initialized
" value: the value the variable should be initialized to
" Returns:
" 1 if the variable was correctly set, 0 otherwise
function s:SvnInitializeVariable (variable, value)
	if !exists (a:variable)
		exec "let " . a:variable . " = '" . a:value . "'"
		return 1
	endif
	return 0
endfunction


" Section: Initialize variables
call s:SvnInitializeVariable ("g:SvnBufferLocation", "left")
call s:SvnInitializeVariable ("g:SvnBufferOrientation", "vertical")
call s:SvnInitializeVariable ("g:SvnBufferSize", 80)
call s:SvnInitializeVariable ("g:SvnBufferIsHidden", 1)
call s:SvnInitializeVariable ("g:SvnBufferShowLines", 0)


" Function: s:SvnCheckDir () {{{2
" This function is intended to check if a directory contains a working copy (i.e
" if it contains a .svn directory)
" Args:
" dir: a string containing the path of the directory to check
" Returns:
" 1 if the directory contains a working copy, 0 otherwise
function! s:SvnCheckDir (dir)
	let svnDir = getcwd ()
	if isdirectory(a:dir) && a:dir != '.'
		let svnDir = a:dir
	endif
	if strlen (svnDir) > 0
		let svnDir = svnDir . '/.svn'
	else
		let svnDir = '.svn
	endif
	return isdirectory (strlen (svnDir))
endfunction


" Function: s:SvnCheckBufferPath () {{{2
" This function is intended to check if the file associated to a buffer is in a
" workin copy.
" Args:
" buffer: the buffer containing the file to be checked.
" Returns:
" 1 if the file is in a working directory, 0 otherwise
function! s:SvnCheckBufferPath (buffer)
	let filename = resolve (bufname(a:buffer))
	if isdirectory(filename)
		return s:SvnCheckDir (filename)
	else
		return s:SvnCheckDir (fnamemodify (filename, ':p:h'))
	endif
endfunction


" Function: s:SvnCreateBuffer () {{{2
" This function creates a new buffer, using plugin variables.
" The new buffer will contain the content argument
" Args:
" content: the content the new buffer should contain
function! s:SvnCreateBuffer (content)
	" Create the buffer
	let buf_location = (g:SvnBufferLocation == "left") ? "topleft ": "topright "
	let buf_orientation = (g:SvnBufferOrientation == "vertical") ? "vertical " : ""
	let buf_size = g:SvnBufferSize
	let t:SvnBufferName = localtime ()
	let cmd = buf_location . buf_orientation . buf_size . ' new ' . t:SvnBufferName
	silent! execute cmd
	" Throwaway buffer options if necessary. This can be very useful for
	" other plugins like FuzzyFinder or BufExplorer, as you don't necessary
	" want this buffer to appear in the buffer list.
	if g:SvnBufferIsHidden
		setlocal readonly
		setlocal modifiable
		setlocal noswapfile
		setlocal buftype=nofile
		setlocal bufhidden=delete
		setlocal nowrap
		setlocal foldcolumn=0
		setlocal nobuflisted
		setlocal nospell
		if g:SvnBufferShowLines
			setlocal nu
		else
			setlocal nonu
		endif
	endif
	" Put the content into the new buffer
	silent put=a:content
	" Set the filetype of the new buffer to svnplugin
	"setfiletype svnplugin
	"if has ("syntax") && exists ("g:syntax_on") && !has ("syntax_items")
	"	FIXME
	"endif
endfunction


command! -nargs=1 SvnCreateBuffer	call s:SvnCreateBuffer(<q-args>)
command! -nargs=1 SvnCheckDir		call s:SvnCheckDir(<q-args>)
command! -nargs=1 SvnCheckBufferPath	call s:SvnCheckBufferPath(<q-args>)
