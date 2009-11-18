" vim600: set foldmethod=marker:
"
" File: svn.vim
" Brief: svn integration plugin for vim
" Author: Scyn - Remi Chaintron <remi.chaintron@gmail.com>
" Url: http:/github.com/scyn-conf/svn-vim
"



" Section: Variable initialization {{{1
" Function: s:_initializeVariable () {{{2
" This function is intended to provide variable initialization, only in the case
" the variable does not exist.
" Args:
" variable: a string containing the name of the variable to be initialized
" value: the value the variable should be initialized to
" Returns:
" 1 if the variable was correctly set, 0 otherwise
function s:_initializeVariable (variable, value)
	if !exists (a:variable)
		exec "let " . a:variable . " = '" . a:value . "'"
		return 1
	endif
	return 0
endfunction

" Section: initializations {{{2
call s:_initializeVariable ("g:SvnBufferLocation", "left")
call s:_initializeVariable ("g:SvnBufferOrientation", "vertical")
call s:_initializeVariable ("g:SvnBufferSize", 80)
call s:_initializeVariable ("g:SvnBufferIsHidden", 1)
call s:_initializeVariable ("g:SvnBufferShowLines", 0)
call s:_initializeVariable ("g:SvnBinary", '/usr/bin/svn')



" Section: Utility functions {{{1
" Function: s:_getKey () {{{2
" This function search for key in dictionnary.
" Args:
" key: the key to look for
" dict: the dictionnary to search in
" Returns:
" The value of the key if the dictionnary has it, 0 otherwise
function! s:_getKey(key, dict)
	if has_key (a:dict, a:key)
		return a:dict[a:key]
	else
		return 0
	endif
endfunction


" Function: s:_changeDirectory () {{{2
" Change cwd to dir argument.
" Args:
" dir: the new cwd
" Returns:
" the old working directory
function! s:_changeDirectory(dir)
	" If it is a file, use s:_changeDirectory instead
	if !isdirectory (dir)
		return s:_changeDirectory (s:_getFileDir (a:dir))
	let oldCwd = getcwd ()
	let cmd = 'cd'
	" if the the current window has set a local path, use it
	if exists ("*haslocaldir") && haslocaldir ()
		let cmd = 'lcd'
	endif
	execute cmd escape (a:dir, ' ')
	return oldCwd
endfunction


" Function: s:_getAbsolutePath () {{{2
" Returns: the absolute path of the argument file
function! s:_getAbsolutePath(file)
	return fnamemodify (bufname(a:file), ':p')
endfunction


" Function: s:_getRelativePath () {{{2
" Returns: the relative path of the argument file
function! s:_getRelativePath(file)
	return fnamemodify (bufname(a:file), ':p:.')
endfunction


" Function: s:_getFileDir () {{{2
" Returns: the directory containing the argument file (relative path)
function! s:_getFileDir(file)
	return fnamemodify (bufname(a:file), ':h')
endfunction


" Function: s:_getFileName () {{{2
" Returns: the name of the argument file
function! s:_getFileName(file)
	return fnamemodify (bufname(a:file), ':t')
endfunction


" Function: s:SvnCheckDir () {{{2
" This function is intended to check if a directory contains a working copy (i.e
" if it contains a .svn directory)
" Args:
" dir: a string containing the path of the directory to check
" Returns:
" 1 if the directory contains a working copy, 0 otherwise
function! s:SvnCheckDir (dir)
	let svnDir = getcwd ()
	if  a:dir != '.' && isdirectory(a:dir)
		let svnDir = a:dir
	endif
	if strlen (svnDir) > 0
		let svnDir = svnDir . '/.svn'
	else
		let svnDir = '.svn
	endif
	return isdirectory (svnDir) ? 1 : 0
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


" Function: s:_createBuffer () {{{2
" This function creates a new buffer, using plugin variables.
" The new buffer will contain the content argument
" Args:
" content: the content the new buffer should contain
" name: The name of the new buffer
function! s:_createBuffer (content, name, options)
	if a:content == 'Error'
		return
	endif
	" Create the buffer
	let buf_location = (g:SvnBufferLocation == "left") ? "topleft ": "topright "
	let buf_orientation = (g:SvnBufferOrientation == "vertical") ? "vertical " : ""
	let buf_size = g:SvnBufferSize
	let cmd = buf_location . buf_orientation . buf_size . ' new ' . a:name
	silent! execute cmd
	" Throwaway buffer options if necessary. This can be very useful for
	" other plugins like FuzzyFinder or BufExplorer, as you don't necessary
	" want this buffer to appear in the buffer list.
	if g:SvnBufferIsHidden
		setlocal nobuflisted
	endif
	setlocal buftype=acwrite
	setlocal readonly
	setlocal modifiable
	setlocal bufhidden=delete
	setlocal noswapfile
	setlocal nowrap
	setlocal foldcolumn=0
	setlocal nospell
	if g:SvnBufferShowLines
		setlocal nu
	else
		setlocal nonu
	endif
	" Put the content into the new buffer
	silent put=a:content
	set nomodified
	" Set the filetype of the new buffer to svnplugin
	"setfiletype svnplugin
	"if has ("syntax") && exists ("g:syntax_on") && !has ("syntax_items")
	"	FIXME
	"endif
endfunction


" Function: s:SvnGetCommandArg () {{{2
" This function is intended to get the argument of the command to be executed,
" using the options argument. The argument depend on the scope of the command,
" ie if it is applied to the current file, the current file's directory, or the
" current working directory
" Args:
" options: dictonnary containing commmand execution related options.
" Returns:
" A relative path to a file or a directory if the command is local to a file or
" directory, an empty string otherwise.
function! s:SvnGetCommandArg (options)
	" Retrieve informations about the scope of the command
	let dir_scope = s:_getKey ('_localDir', a:options)
	let file_scope = s:_getKey ('_localFile', a:options)
	" Get the argument
	if file_scope
		let filename = s:_getRelativePath ('%')
		return isdirectory (filename) ? '' : filename
	elseif dir_scope
		let dir = s:_getFileDir ('%')
		return isdirectory (dir) ? dir : ''
	else
		return ''
	endif
endfunction


" Function: s:SvnExecuteCommand () {{{2
" This function performs several actions:
" - It first retrieves informations about the command to be executed, such as
"   its scope, then change working directory accordingly and update command to
"   be executed.
" - It executes the command, outputing errors and resetting working after the
"   command terminate.
" Args:
" cmd: string containing the command to be executed
" options: dictionnary containing command execution related options, such as its
" scope.
" Returns:
" A string containing svn output, 'Error' otherwise.
function! s:SvnExecuteCommand(cmd, options)
	" Retrieve command execution options
	let allowNonZeroExit = s:_getKey ('_allowNonZeroExit', a:options)
	" Build command to execute
	let cmd = a:cmd . ' ' . s:SvnGetCommandArg (a:options)
	" Execute the command
	let svn_output = system (g:SvnBinary . " " . cmd)
	" if an error occured, output error, else return svn output
	if v:shell_error && !allowNonZeroExit
		echohl Error
		echo svn_output
		echohl None
		return 'Error'
	else
		return svn_output
	endif
endfunction



" Section: Svn functions implementation {{{1
" Function: s:SvnStatus () {{{2
function! s:SvnStatus(options)
	let result = s:SvnExecuteCommand ('status --non-interactive', a:options)
	call s:_createBuffer (result, '_svn_status', {})
endfunction


" Function: s:SvnLog () {{{2
function! s:SvnLog()
	let result = s:SvnExecuteCommand ('log --verbose', {'_allowNonZeroExit' : 1})
	call s:_createBuffer (result, '_svn_log', {})
endfunction


" Function: s:SvnUpdate () {{{2
function! s:SvnUpdate(args, options)
	let result = s:SvnExecuteCommand ('update --non-interactive ' . a:args, a:options)
	checktime
	call s:_createBuffer (result, '_svn_update', {})
endfunction


" Function: s:SvnCommit () {{{2
function! s:SvnCommit(args, options)
	" Create commit buffer
	let commit_msg = "--This line, and those below, will be ignored--\n\n" . 
				\ s:SvnExecuteCommand ('status -q --non-interactive', a:options)
	let commit_arg = s:SvnGetCommandArg (a:options)
	call s:_createBuffer (commit_msg, '_svn_commit', {})
	setlocal modifiable noreadonly
	augroup SvnCommit
		" When the buffer is written, override its behavior
		execute printf ("autocmd BufWriteCmd <buffer> call s:SvnCommitWrite ('%s') | autocmd! SvnCommit * <buffer>", commit_arg)
	augroup END
	" Go to first line
	goto 1
endfunction


" Function: s:SvnCommitWrite () {{{2
function! s:SvnCommitWrite(arg)
	" Retrieve commit buffer
	let commitBuffer = bufnr('_svn_commit')
	setlocal nomodified
	" Delete epilogue
	%substitute/\-\-[^$]*\-\-\n\(.*\n\)*//g
	" Get the lines of the commit buffer
	let commitMessage = getbufline('%', 1, '$')
	" Write into temporary file rather than original file
	let tmpFile = tempname ()
	call writefile (commitMessage, tmpFile)
	" Execute commit
	let result = s:SvnExecuteCommand ('commit ' . a:arg . ' -F ' . tmpFile, {})
	call delete (tmpFile)
	if !v:shell_error
		execute 'bw!' commitBuffer
	endif
endfunction



" Section: Commands definition {{{1

command! -nargs=0 SvnStatus		call s:SvnStatus ({})
command! -nargs=0 SvnStatusFile		call s:SvnStatus ({'_localFile' : 1})
command! -nargs=0 SvnStatusDir		call s:SvnStatus ({'_localDir' : 1})
command! -nargs=* SvnUpdate		call s:SvnUpdate (<q-args>, {})
command! -nargs=* SvnUpdateFile		call s:SvnUpdate (<q-args>, {'_localFile' : 1})
command! -nargs=* SvnUpdateDir		call s:SvnUpdate (<q-args>, {'_localDir' : 1})
command! -nargs=0 SvnLog		call s:SvnLog ()
command! -nargs=0 SvnCommit		call s:SvnCommit(<q-args>, {})
command! -nargs=0 SvnCommitFile		call s:SvnCommit(<q-args>, {'_localFile' : 1})
command! -nargs=0 SvnCommitDir		call s:SvnCommit(<q-args>, {'_localDir' : 1})
