
#dirStack
============

Plugin for bash prompt for dir bookmarking.
[dir bookmarks](http://vincent.bernat.im/en/blog/2015-zsh-directory-bookmarks.html)

The perfect complement for [z](https://github.com/rupa/z)

Never ever lost an old cd dir again.


##INSTALL

```bash
$cd ~/yourDir
$git clone https://github.com/liloman/dirStack.git 
try it on-fly
$source dirStack/dirStack.sh
or 
$echo ". ~/yourDir/dirStack/dirStack.sh"  >> ~/.bashrc 
```

##Use

You cd into directories as normal and when you lost a directory from "cd -" it will be added to your dirStack automagically. 

So:

```bash
$source dirStack/dirStack.sh
✪ Empty dir stack(a add,d delete,g go number,~num = dir)
$cd /tmp
✪ Empty dir stack(a add,d delete,g go number,~num = dir)
$cd /var
✪ Empty dir stack(a add,d delete,g go number,~num = dir)
$ cd log/
✪ [1:/tmp]
$ cd journal/
✪ [1:/var][2:/tmp]
$ cd ~
✪ [1:/var/log][2:/var][3:/tmp]
$ls ~2/
dm    crash  empty  gopher 
...
✪ [1:/var/log][2:/var][3:/tmp]
$cp -rv ~3/ ~1/dm 
✪ [1:/var/log][2:/var][3:/tmp]
$g 3
✪ [1:/var/log][2:/var][3:/tmp]
$pwd
/tmp
```

##FAQ

###Can I go/add/delete a dirStack?

Absolutely!

It includes the bash aliases (g,a,d).

```bash
✪ [1:/var/log][2:/var][3:/tmp]
$d 2
Deleted /var from dir stack
✪ [1:/var/log][2:/tmp]
$a ~/stuff
✪ [1:~/stuff][2:/var/log][3:/tmp]
$g 1
✪ [1:~/stuff][2:/var/log][3:/tmp]
$d 1 3
Deleted ~/stuff from dir stack
Deleted /tmp from dir stack
✪ [1:/var/log]
$
...
```

###Does it work with autocompletion?

Indeed!

```bash
✪ [1:/var/log][2:/var][3:/tmp]
$mv  ~3/ (TAB)  /old
yourstuf.log somedir/
...
```

###Why not HOME?

Cause you can always use (~) for than but you can customize it with DIRSTACK_EXCLUDE bash variable.
```bash
$DIRSTACK_EXCLUDE="/foobar:/tmp"
```

###How many dirs can it save?

By default 5 but you can customize it. 
```bash
$DIRSTACK_LIMIT=3
```

###Can I disable it temporarily? 


```bash
$DIRSTACK_ENABLED=false
```



## TODO
- [x] del with multiple arguments
- [ ] Screenshots and ~~tutorial~~ (almost)
- [ ] Unit testing? (bats)


