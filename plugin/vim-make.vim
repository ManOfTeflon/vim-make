
let s:Plugin = {}
let s:MakePlugin = {}
function! s:Plugin.Activate(path)
    if len(a:path.pathSegments) < 2
        return
    endif
    let file = join(a:path.pathSegments[:-2], '/')
    let nr = split(a:path.pathSegments[-1], ':')[0]
    exec 'edit +' . nr . ' ' . file
endfunction

function! s:MakePlugin.Activate(path)
    let line = a:path.pathSegments[-1]
    let tokens = matchlist(line, '\d\+:\s\+\(.\+\):\(\d\+\):\(\d\+\):.*')
    if len(tokens) > 0
        exec 'edit +' . tokens[2] . ' ' . tokens[1]
        exec 'norm ' . tokens[3] . '|'
    endif
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
    let lines = split(system("git grep -n '" . a:word . "'"), '\n')
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

    call NERDTreeFromJSON(files, s:Plugin)
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

    call NERDTreeFromJSON(files, s:Plugin)
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

    call NERDTreeFromJSON(files, s:Plugin)
endfunction

function! s:RemoteMake()
    let json = system('netcat 127.0.0.1 8642')
    let d = pyeval("json.loads(vim.eval('l:json'))")
    let files = {}

    for [ file, errors ] in items(d)
        let lines = split(errors, "\n")
        let digits = len(printf("%d", len(lines)))
        let nr = 1
        for line in lines
            if len(line)
                call s:BuildDict(files, s:Relpath(file), printf("%0" . digits . "d", nr), s:Relpath(line))
                let nr = nr + 1
            endif
        endfor
    endfor

    call NERDTreeFromJSON(files, s:MakePlugin)
endfunction

command! -nargs=0 RemoteMake call s:RemoteMake()

command! -nargs=1 VimGrep call s:_VimGrep(<f-args>)
command! -nargs=0 QFixTree call s:QFixTree()
command! -nargs=? LocListTree call s:LocListTree(<f-args>)

command! -nargs=? Lopen LocListTree 0
command! -nargs=? Copen QFixTree

