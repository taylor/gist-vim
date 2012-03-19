"=============================================================================
" File: gist.vim
" Author: Yasuhiro Matsumoto <mattn.jp@gmail.com>
" Last Change: 19-Mar-2012.
" Version: 5.9
" WebPage: http://github.com/mattn/gist-vim
" License: BSD
" Usage:
"
"   :Gist
"     post current buffer to gist, using default privicy option
"     (see g:gist_private)
"
"   :'<,'>Gist
"     post selected text to gist., using default privicy option
"     This applies to all permutations listed below (except multi)
"     (see g:gist_private)
"
"   :Gist -p
"     create a private gist
"
"   :Gist -P
"     create a public gist
"     (only relevant if you've set gists to be private by default)
"
"   :Gist -P
"     post whole text to gist as public
"     This is only relevant if you've set gists to be private by default
"   :Gist -a
"     create a gist anonymously
"
"   :Gist -m
"     create a gist with all open buffers
"
"   :Gist -e
"     edit the gist. (you need to have opend the gist buffer first)
"     you can update the gist with :w command on gist buffer
"
"   :Gist -d
"     delete the gist. (you need to have opend the gist buffer first)
"     password authentication is needed
"
"   :Gist -f
"     fork the gist. (you need to have opend the gist buffer first)
"     password authentication is needed
"
"   :Gist -e foo.js
"     edit the gist with name 'foo.js'. (you need to have opend the gist buffer first)
"
"   :Gist XXXXX
"     get gist XXXXX
"
"   :Gist -c XXXXX
"     get gist XXXXX and add to clipboard
"
"   :Gist -l
"     list your public gists
"
"   :Gist -l mattn
"     list gists from mattn
"
"   :Gist -la
"     list all your (public and private) gists
"
" Tips:
"   * if set g:gist_clip_command, gist.vim will copy the gist code
"       with option '-c'.
"
"     # mac
"     let g:gist_clip_command = 'pbcopy'
"
"     # linux
"     let g:gist_clip_command = 'xclip -selection clipboard'
"
"     # others(cygwin?)
"     let g:gist_clip_command = 'putclip'
"
"   * if you want to detect filetype from gist's filename...
"
"     # detect filetype if vim failed auto-detection.
"     let g:gist_detect_filetype = 1
"
"     # detect filetype always.
"     let g:gist_detect_filetype = 2
"
"   * if you want to open browser after the post...
"
"     let g:gist_open_browser_after_post = 1
"
"   * if you want to change the browser...
"
"     let g:gist_browser_command = 'w3m %URL%'
"
"       or
"
"     let g:gist_browser_command = 'opera %URL% &'
"
"     on windows, should work with original setting.
"
"   * if you want to show your private gists with ':Gist -l'
"
"     let g:gist_show_privates = 1
"
"   * if don't you want to copy URL of the post...
"
"     let g:gist_put_url_to_clipboard_after_post = 0
"
"     or if you want to copy URL and add linefeed at the last of URL,
"
"     let g:gist_put_url_to_clipboard_after_post = 2
"
"     default value is 1.
"

let s:save_cpo = &cpo
set cpo&vim

if !exists('g:gist_open_browser_after_post')
  let g:gist_open_browser_after_post = 0
endif

if !exists('g:gist_put_url_to_clipboard_after_post')
  let g:gist_put_url_to_clipboard_after_post = 1
endif

if !exists('g:gist_keep_selection')
  let g:gist_keep_selection = 0
endif

if !exists('g:gist_browser_command')
  if has('win32') || has('win64')
    let g:gist_browser_command = "!start rundll32 url.dll,FileProtocolHandler %URL%"
  elseif has('mac')
    let g:gist_browser_command = "open %URL%"
  elseif executable('xdg-open')
    let g:gist_browser_command = "xdg-open %URL%"
  else
    let g:gist_browser_command = "firefox %URL% &"
  endif
endif

if !exists('g:gist_detect_filetype')
  let g:gist_detect_filetype = 0
endif

if !exists('g:gist_private')
  let g:gist_private = 0
endif

if !exists('g:gist_show_privates')
  let g:gist_show_privates = 0
endif

function! s:shellwords(str)
  let words = split(a:str, '\%(\([^ \t\''"]\+\)\|''\([^\'']*\)''\|"\(\%([^\"\\]\|\\.\)*\)"\)\zs\s*\ze')
  let words = map(words, 'substitute(v:val, ''\\\([\\ ]\)'', ''\1'', "g")')
  let words = map(words, 'matchstr(v:val, ''^\%\("\zs\(.*\)\ze"\|''''\zs\(.*\)\ze''''\|.*\)$'')')
  return words
endfunction

function! s:format_gist(gist)
  let files = sort(keys(a:gist.files))
  let file = a:gist.files[files[0]]
  if has_key(file, "content")
    let code = file.content
    let code = "\n".join(map(split(code, "\n"), '"  ".v:val'), "\n")
  else
    let code = ""
  endif
  return printf("gist: %s %s%s", a:gist.id, type(a:gist.description)==0?"": a:gist.description, code)
endfunction

" Note: A colon in the file name has side effects on Windows due to NTFS Alternate Data Streams; avoid it. 
let s:bufprefix = 'gist' . (has('unix') ? ':' : '_')
function! s:GistList(gistls, page)
  if a:gistls == '-all'
    let url = 'https://api.github.com/gists/public'
  elseif g:gist_show_privates && a:gistls == 'starred'
    let url = 'https://api.github.com/gists/starred'
  elseif g:gist_show_privates || a:gistls == 'mine'
    let url = 'https://api.github.com/gists'
  else
    let url = 'https://api.gist.github.com/gists/'.a:gistls
  endif
  let winnum = bufwinnr(bufnr(s:bufprefix.a:gistls))
  if winnum != -1
    if winnum != bufwinnr('%')
      exe winnum 'wincmd w'
    endif
    setlocal modifiable
  else
    exec 'silent noautocmd split' s:bufprefix.a:gistls
  endif
  if a:page > 1
    let oldlines = getline(0, line('$'))
    let url = url . '?page=' . a:page
  endif

  setlocal modifiable
  setlocal foldmethod=manual
  let old_undolevels = &undolevels
  let oldlines = []
  silent %d _

  redraw | echon 'Login to gist... '
  let ctx = s:GetOAuthCtx()
  redraw | echon 'Listing gists... '
  let res = http#get(url, ctx)
  if v:shell_error != 0
    bw!
    redraw
    echohl ErrorMsg | echomsg 'Gist not found' | echohl None
    return
  endif

  let lines = map(json#decode(res.content), 's:format_gist(v:val)')
  call setline(1, split(join(lines, "\n"), "\n"))

  $put='more...'

  let b:gistls = a:gistls
  let b:page = a:page
  setlocal buftype=nofile bufhidden=hide noswapfile
  setlocal nomodified
  setlocal nomodifiable
  syntax match SpecialKey /^gist:/he=e-1
  nnoremap <silent> <buffer> <cr> :call <SID>GistListAction(0)<cr>
  nnoremap <silent> <buffer> <s-cr> :call <SID>GistListAction(1)<cr>

  cal cursor(1+len(oldlines),1)
  setlocal foldmethod=expr
  setlocal foldexpr=getline(v:lnum)=~'^\\(gist:\\\|more\\)'?'>1':'='
  setlocal foldtext=getline(v:foldstart)
  nohlsearch
  redraw | echo ''
endfunction

function! s:GistGetFileName(gistid)
  let ctx = s:GetOAuthCtx()
  let res = http#get('https://api.github.com/gists/'.a:gistid, ctx)
  let gist = json#decode(res.content)
  return sort(keys(gist.files))[0]
endfunction

function! s:GistDetectFiletype(gistid)
  let ctx = s:GetOAuthCtx()
  let res = http#get('https://api.github.com/gists/'.a:gistid, ctx)
  let gist = json#decode(res.content)
  let filename = sort(keys(gist.files))[0]
  let type = get(gist.files[filename], "type", "text")
  silent! exec "setlocal ft=".tolower(type)
endfunction

function! s:GistWrite(fname)
  if substitute(a:fname, '\\', '/', 'g') == expand("%:p:gs@\\@/@")
    Gist -e
  else
    exe "w".(v:cmdbang ? "!" : "") fnameescape(v:cmdarg) fnameescape(a:fname)
    silent! exe "file" fnameescape(a:fname)
    silent! au! BufWriteCmd <buffer>
  endif
endfunction

function! s:GistGet(gistid, clipboard)
  let winnum = bufwinnr(bufnr(s:bufprefix.a:gistid))
  if winnum != -1
    if winnum != bufwinnr('%')
      exe winnum 'wincmd w'
    endif
    setlocal modifiable
  else
    exec 'silent noautocmd split' s:bufprefix.a:gistid
  endif
  let old_undolevels = &undolevels
  set undolevels=-1
  filetype detect
  silent %d _
  let ctx = s:GetOAuthCtx()
  let res = http#get('https://api.github.com/gists/'.a:gistid, ctx)
  let status = matchstr(matchstr(res.header, '^Status:'), '^[^:]\+: \zs.*')
  if status =~ '^2'
    call writefile(split(res.content, "\n"), "myjson.js")
    try
      let gist = json#decode(res.content)
      let filename = sort(keys(gist.files))[0]
      let content = obj.[filename].content
      call setline(1, split(join(content, "\n"), "\n"))
    catch
      let &undolevels = old_undolevels
      bw!
      redraw
      echohl ErrorMsg | echomsg 'Gist contains binary' | echohl None
      return
    endtry
  else
    let &undolevels = old_undolevels
    bw!
    redraw
    echohl ErrorMsg | echomsg 'Gist not found' | echohl None
    return
  endif
  let &undolevels = old_undolevels
  setlocal buftype=acwrite bufhidden=delete noswapfile
  setlocal nomodified
  doau StdinReadPost <buffer>
  if (&ft == '' && g:gist_detect_filetype == 1) || g:gist_detect_filetype == 2
    call s:GistDetectFiletype(a:gistid)
  endif
  if a:clipboard
    if exists('g:gist_clip_command')
      exec 'silent w !'.g:gist_clip_command
    elseif has('clipboard')
      silent! %yank +
    else
      %yank
    endif
  endif
  1
  au! BufWriteCmd <buffer> call s:GistWrite(expand("<amatch>"))
endfunction

function! s:GistListAction(shift)
  let line = getline('.')
  let mx = '^gist:\s*\zs\(\w\+\)\ze.*'
  if line =~# mx
    let gistid = matchstr(line, mx)
    if a:shift
      let url = "https://gist.github.com/" . gistid
      let cmd = substitute(g:gist_browser_command, '%URL%', url, 'g')
      if cmd =~ '^!'
        silent! exec cmd
      elseif cmd =~ '^:[A-Z]'
        exec cmd
      else
        call system(cmd)
      endif
    else
      call s:GistGet(gistid, 0)
    endif
    return
  endif
  if line =~# '^more\.\.\.$'
    call s:GistList(b:gistls, b:page+1)
    return
  endif
endfunction

function! s:GistUpdate(content, gistid, gistnm, desc)
  let gist = { "id": a:gistid, "files" : {}, "description": "","public": function('json#true') }
  if a:desc != ' ' | let gist["description"] = a:desc | endif
  if a:private | let gist["public"] = function('json#false') | endif
  let filename = a:gistnm
  if len(a:gistnm) == 0
    let filename = s:GistGetFileName(a:gistid)
  endif
  elseif len(filename) == 0
    let filename = 'file1.txt'
  endif
  let gist.files[filename] = { "content": a:content }

  redraw | echon 'Login to gist... '
  let ctx = s:GetOAuthCtx()
  redraw | echon 'Posting it to gist... '
  let res = http#post('https://api.github.com/gists',
  \ json#encode(gist), {"Authorization": printf("token %s", ctx.access_token) })
  let status = matchstr(matchstr(res.header, '^Status:'), '^[^:]\+: \zs.*')
  if status =~ '^2'
    let obj = json#decode(res.content)
    redraw
    echomsg 'Done: '.loc
    let loc = obj["html_url"]
  else
    let status = matchstr(status, '^\d\+\s*\zs.*')
    echohl ErrorMsg | echomsg 'Post failed: '.status | echohl None
    let loc = ''
  endif
  return loc
endfunction

function! s:GistDelete(gistid)
  redraw | echon 'Login to gist... '
  let ctx = s:GetOAuthCtx()
  redraw | echon 'Deleting to gist... '
  let res = http#post('https://api.github.com/gists/'.a:gistid, '', {"Authorization": printf("token %s", ctx.access_token) }, 'DELETE')
  let status = matchstr(matchstr(res.header, '^Status:'), '^[^:]\+: \zs.*')
  if status =~ '^2'
    redraw | echomsg 'Done: '
  else
    let status = matchstr(status, '^\d\+\s*\zs.*')
    echohl ErrorMsg | echomsg 'Delete failed: '.status | echohl None
  endif
endfunction

" GistPost function:
"   Post new gist to github
"
"   if there is an embedded gist url or gist id in your file,
"   it will just update it.
"                                                   -- by c9s
"
"   embedded gist url format:
"
"       Gist: https://gist.github.com/123123
"
"   embedded gist id format:
"
"       GistID: 123123
"
function! s:GistPost(content, private, desc)
  let gist = { "files" : {}, "description": "","public": function('json#true') }
  if a:desc != ' ' | let gist["description"] = a:desc | endif
  if a:private | let gist["public"] = function('json#false') | endif
  let filename = expand('%:t')
  if len(filename) == 0
    let filename = 'gistfile1.txt'
  endif
  let gist.files[filename] = { "content": a:content }

  redraw | echon 'Login to gist... '
  let ctx = s:GetOAuthCtx()
  redraw | echon 'Posting it to gist... '
  let res = http#post('https://api.github.com/gists',
  \ json#encode(gist), {"Authorization": printf("token %s", ctx.access_token) })
  let status = matchstr(matchstr(res.header, '^Status:'), '^[^:]\+: \zs.*')
  if status =~ '^2'
    let obj = json#decode(res.content)
    redraw
    echomsg 'Done: '.loc
    let loc = obj["html_url"]
  else
    let status = matchstr(status, '^\d\+\s*\zs.*')
    echohl ErrorMsg | echomsg 'Post failed: '.status | echohl None
    let loc = ''
  endif
  return loc
endfunction

function! s:GistPostBuffers(private, desc)
  let bufnrs = range(1, bufnr("$"))
  let bn = bufnr('%')
  let query = []

  let gist = { "files" : {}, "description": "","public": function('json#true') }
  if a:desc != ' ' | let gist["description"] = a:desc | endif
  if a:private | let gist["public"] = function('json#false') | endif

  let index = 1
  for bufnr in bufnrs
    if !bufexists(bufnr) || buflisted(bufnr) == 0
      continue
    endif
    echo "Creating gist content".index."... "
    silent! exec "buffer!" bufnr
    let content = join(getline(1, line('$')), "\n")
    let filename = expand('%:t')
    if len(filename) == 0
      let filename = 'file1.txt'
    endif
    let gist.files[filename] = { "content": content }

    let index = index + 1
  endfor
  silent! exec "buffer!" bn

  redraw | echon 'Login to gist... '
  let ctx = s:GetOAuthCtx()
  redraw | echon 'Posting it to gist... '
  let res = http#post('https://api.github.com/gists',
  \ json#encode(gist), {"Authorization": printf("token %s", ctx.access_token) })
  let status = matchstr(matchstr(res.header, '^Status:'), '^[^:]\+: \zs.*')
  if status =~ '^2'
    let obj = json#decode(res.content)
    redraw
    echomsg 'Done: '.loc
    let loc = obj["html_url"]
  else
    let status = matchstr(status, '^\d\+\s*\zs.*')
    echohl ErrorMsg | echomsg 'Post failed: '.status | echohl None
    let loc = ''
  endif
  return loc
endfunction

function! gist#Gist(count, line1, line2, ...)
  redraw
  if !exists('g:github_user')
    let g:github_user = substitute(system('git config --global github.user'), "\n", '', '')
    if strlen(g:github_user) == 0
      let g:github_user = $GITHUB_USER
    end
  endif
  let bufname = bufname("%")
  let gistid = ''
  let gistls = ''
  let gistnm = ''
  let gistdesc = ' '
  let private = g:gist_private
  let multibuffer = 0
  let clipboard = 0
  let deletepost = 0
  let editpost = 0
  let listmx = '^\%(-l\|--list\)\s*\([^\s]\+\)\?$'
  let bufnamemx = '^' . s:bufprefix .'\zs\([0-9a-f]\+\)\ze$'

  let args = (a:0 > 0) ? s:shellwords(a:1) : []
  for arg in args
    if arg =~ '^\(-la\|--listall\)$\C'
      let gistls = '-all'
    elseif arg =~ '^\(-ls\|--liststar\)$\C'
      let gistls = 'starred'
    elseif arg =~ '^\(-l\|--list\)$\C'
      if g:gist_show_privates
        let gistls = 'mine'
      else
        let gistls = g:github_user
      endif
    elseif arg =~ '^\(-m\|--multibuffer\)$\C'
      let multibuffer = 1
    elseif arg =~ '^\(-p\|--private\)$\C'
      let private = 1
    elseif arg =~ '^\(-P\|--public\)$\C'
      let private = 0
    elseif arg =~ '^\(-s\|--description\)$\C'
      let gistdesc = ''
    elseif arg =~ '^\(-c\|--clipboard\)$\C'
      let clipboard = 1
    elseif arg =~ '^\(-d\|--delete\)$\C' && bufname =~ bufnamemx
      let deletepost = 1
      let gistid = matchstr(bufname, bufnamemx)
    elseif arg =~ '^\(-e\|--edit\)$\C' && bufname =~ bufnamemx
      let editpost = 1
      let gistid = matchstr(bufname, bufnamemx)
    elseif arg =~ '^\(+1\|--star\)$\C' && bufname =~ bufnamemx
      let gistid = matchstr(bufname, bufnamemx)
      let res = http#post("https://api.github.com/gists/".gistid."/star", "", {}, "PUT")
      let status = matchstr(matchstr(res.header, '^Status:'), '^[^:]\+: \zs.*')
      if status =~ '^2'
        echomsg "Stared" gistid
      else
        echohl ErrorMsg | echomsg 'Star failed' | echohl None
      endif
      return
    elseif arg =~ '^\(-1\|--unstar\)$\C' && bufname =~ bufnamemx
      let gistid = matchstr(bufname, bufnamemx)
      let res = http#post("https://api.github.com/gists/".gistid."/star", "", {}, "DELETE")
      if status =~ '^2'
        echomsg "Unstared" gistid
      else
        echohl ErrorMsg | echomsg 'Unstar failed' | echohl None
      endif
      return
    elseif arg =~ '^\(-f\|--fork\)$\C' && bufname =~ bufnamemx
      let gistid = matchstr(bufname, bufnamemx)
      let res = http#post("https://api.github.com/gists/".gistid."/fork", "")
      let status = matchstr(matchstr(res.header, '^Status:'), '^[^:]\+: \zs.*')
      if status =~ '^2'
        let obj = json#decode(res.content)
        let gistid = obj["id"]
      else
        echohl ErrorMsg | echomsg 'Fork failed' | echohl None
        return
      endif
    elseif arg !~ '^-' && len(gistnm) == 0
      if gistdesc != ' '
        let gistdesc = matchstr(arg, '^\s*\zs.*\ze\s*$')
      elseif editpost == 1 || deletepost == 1
        let gistnm = arg
      elseif len(gistls) > 0 && arg != '^\w\+$\C'
        let gistls = arg
      elseif arg =~ '^[0-9a-z]\+$\C'
        let gistid = arg
      else
        echohl ErrorMsg | echomsg 'Invalid arguments' | echohl None
        unlet args
        return 0
      endif
    elseif len(arg) > 0
      echohl ErrorMsg | echomsg 'Invalid arguments' | echohl None
      unlet args
      return 0
    endif
  endfor
  unlet args
  "echo "gistid=".gistid
  "echo "gistls=".gistls
  "echo "gistnm=".gistnm
  "echo "gistdesc=".gistdesc
  "echo "private=".private
  "echo "clipboard=".clipboard
  "echo "editpost=".editpost
  "echo "deletepost=".deletepost

  if len(gistls) > 0
    call s:GistList(gistls, 1)
  elseif len(gistid) > 0 && editpost == 0 && deletepost == 0
    call s:GistGet(gistid, clipboard)
  else
    let url = ''
    if multibuffer == 1
      let url = s:GistPostBuffers(private, gistdesc)
    else
      if a:count < 1
        let content = join(getline(a:line1, a:line2), "\n")
      else
        let save_regcont = @"
        let save_regtype = getregtype('"')
        silent! normal! gvy
        let content = @"
        call setreg('"', save_regcont, save_regtype)
      endif
      if editpost == 1
        let url = s:GistUpdate(content, gistid, gistnm, gistdesc)
      elseif deletepost == 1
        call s:GistDelete(gistid)
      else
        let url = s:GistPost(content, private, gistdesc)
      endif
      if a:count >= 1 && g:gist_keep_selection
        silent! normal! gv
      endif
    endif
    if len(url) > 0
      if g:gist_open_browser_after_post
        let cmd = substitute(g:gist_browser_command, '%URL%', url, 'g')
        if cmd =~ '^!'
          silent! exec cmd
        elseif cmd =~ '^:[A-Z]'
          exec cmd
        else
          call system(cmd)
        endif
      endif
      if g:gist_put_url_to_clipboard_after_post > 0
        if g:gist_put_url_to_clipboard_after_post == 2
          let url = url . "\n"
        endif
        if exists('g:gist_clip_command')
          call system(g:gist_clip_command, url)
        elseif has('unix') && !has('xterm_clipboard')
          let @" = url
        else
          let @+ = url
        endif
      endif
    endif
  endif
  return 1
endfunction

function! s:GetOAuthCtx()
  let ctx = {}
  let configfile = expand('~/.gist-vim')
  if filereadable(configfile)
    let obj = eval(join(readfile(configfile), ""))
    if type(obj) == 4
      let ctx = obj
    endif
  endif
  if empty(ctx)
    let auth_url =  "https://github.com/login/oauth/authorize"
    let access_token_url = "https://github.com/login/oauth/access_token"
    let client_id = input("ClientID:")
    let client_secret = input("ClientSecret:")

    if has("win32") || has("win64")
      silent exe "!start rundll32 url.dll,FileProtocolHandler ".auth_url."?scope=gist&client_id=".client_id
    else
      silent call system("xdg-open '".auth_url."?scope=gist&client_id=".client_id."'")
    endif
    let pin = input("PIN:")
    redraw | echo ""
    let res = http#post(access_token_url, {"client_id": client_id, "code": pin, "client_secret": cilent_secret})
    for item in split(res.content, '&')
      let token = split(item, '=')
      if len(token) != 2
        continue
      endif
      if token[0] == 'access_token'
        let ctx['access_token'] = http#decodeURI(token[1])
      endif
    endfor
    call writefile([string(ctx)], configfile)
  endif
  return ctx
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo

" vim:set et:
