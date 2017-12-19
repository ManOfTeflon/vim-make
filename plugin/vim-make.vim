let s:JumpPlugin = NERDTreeCreatePlugin()
function! s:JumpPlugin.New(tree)
    let obj = copy(self)
    let obj._tree = a:tree
endfunction
function! a:JumpPlugin.ParsePath(str)
endfunction
function! s:JumpPlugin.Activate(path)
    if len(a:path.pathSegments) < 2
        return
    endif
    let file = join(a:path.pathSegments[:-2], '/')
    let nr = split(a:path.pathSegments[-1], ':')[0]
    exec 'edit +' . nr . ' ' . file
endfunction

let s:LJumpPlugin = NERDTreeCreatePlugin()
function! s:LJumpPlugin.Activate(path)
    call s:JumpPlugin.Activate(a:path)
    call nerdtree#closeTreeIfOpen()
endfunction

let s:GdbPlugin = NERDTreeCreatePlugin()
function! s:GdbPlugin.Activate(path)
    let core = a:path.pathSegments[-1]
    call s:DebugCore(core)
endfunction

function! s:CreateTree(files, plugin, pos, size)
    let oldPos = g:NERDTreeWinPos
    let oldSize = g:NERDTreeWinSize

    let g:NERDTreeWinPos = a:pos
    let g:NERDTreeWinSize = a:size
    call NERDTreeFromJSON(a:files, a:plugin)

    let g:NERDTreeWinPos = oldPos
    let g:NERDTreeWinSize = oldSize
endfunction

function! s:BuildDict(files, file, nr, line)
    let parts = split(a:file, '/')
    let d = a:files
    for part in parts
        if ! has_key(d, part) || type(d[part]) != type({})
            let d[part] = {}
        endif
        let d = d[part]
    endfor

    let d[a:nr . ": " . a:line] = 0

    return a:files
endfunction

function! s:_VimGrep(word)
    let lines = split(system("git grep -n '" . a:word . "' -- ':/'"), '\n')
    echo "found " . len(lines) . " occurences"
    let files = {}
    for line in lines
        let tokens = split(line, ':')
        let idx = stridx(line, ':')
        let idx = stridx(line, ':', idx + 1)
        let line = substitute(strpart(line, idx + 1), '^\s*\(.\{-}\)\s*$', '\1', '')
        if len(tokens) < 2
            let files[line] = 0
        else
            let [ file, nr ] = [ tokens[0], tokens[1] ]
            call s:BuildDict(files, file, nr, line)
        endif
    endfor

    call s:CreateTree(files, s:JumpPlugin, g:NERDTreeWinPos, g:NERDTreeWinSize)
endfunction

function! s:Relpath(file)
    return substitute(a:file, '^' . getcwd() . '/', '', '')
endfunction

function! s:QFixTree()
    cclose
    let files = {}
    for d in getqflist()
        call s:BuildDict(files, s:Relpath(bufname(d.bufnr)), d.lnum, d.text)
    endfor

    call s:CreateTree(files, s:JumpPlugin, g:NERDTreeWinPos, g:NERDTreeWinSize)
endfunction

function! s:LocListTree(...)
    lclose
    if a:0 == 0
        let winnr = 0
    else
        let winnr = a:1
    endif

    let files = {}
    for d in getloclist(winnr)
        call s:BuildDict(files, s:Relpath(bufname(d.bufnr)), d.lnum, d.text)
    endfor

    call s:CreateTree(files, s:JumpPlugin, g:NERDTreeWinPos, g:NERDTreeWinSize)
endfunction

function! s:LocListJump(...)
    lclose
    if a:0 == 0
        let winnr = 0
    else
        let winnr = a:1
    endif

    let files = {}
    let loclist = getloclist(winnr)
    if len(loclist) == 0
        echoerr "No results found!"
    elseif len(loclist) == 1
        let d = loclist[0]
        let file = bufname(d.bufnr)
        let nr = d.lnum
        exec 'edit +' . nr . ' ' . file
    else
        for d in loclist
            call s:BuildDict(files, s:Relpath(bufname(d.bufnr)), d.lnum, d.text)
        endfor

        call s:CreateTree(files, s:LJumpPlugin, "bottom", 30)
        call b:NERDTreeRoot.openRecursively()
        call nerdtree#renderView()
    endif
endfunction

function s:DebugCore(path)
    let core = a:path
    let logs = join(split(a:path, '/')[:-2], '/') . '/../tracelogs/memsql.log'
    echo logs
    exec "GdbStartDebugger --log=" . logs . " -c " . core . " ./memsqld"
    call nerdtree#closeTreeIfOpen()
endfunction

function! s:FindCores()
    let cores = split(system("find . -name 'core.memsqld.*' | cut -c3-"), '\n')
    let tree = { 'cores': {} }
    for core in cores
        let tree['cores'][core] = 0
    endfor

    call s:CreateTree(tree, s:GdbPlugin, g:NERDTreeWinPos, g:NERDTreeWinSize)
    call b:NERDTreeRoot.openRecursively()
    call nerdtree#renderView()
endfunction

command! -nargs=0 FindCores call s:FindCores()
command! -nargs=1 DebugCore call s:DebugCore(<q-args>)

command! -nargs=1 VimGrep call s:_VimGrep(<f-args>)
command! -nargs=0 QFixTree call s:QFixTree()
command! -nargs=? LocListTree call s:LocListTree(<f-args>)
command! -nargs=? LocListJump call s:LocListJump(<f-args>)

command! -nargs=0 Lopen LocListTree 0
command! -nargs=0 Ljump LocListJump 0
command! -nargs=0 Copen QFixTree

