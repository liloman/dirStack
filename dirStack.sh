#!/usr/bin/env bash
#Keep a dir bookmarking of the N recently-entered dirs

######################
#  Dir stack prompt  #
######################

#Enable plugin
DIRSTACK_ENABLED=true
#Maximum dir stack size
DIRSTACK_LIMIT=5
# Full paths to exclude from dir stack separated by colon
DIRSTACK_EXCLUDE="/foobar:$HOME"
#State for FSM (default excluded)
DIRSTACK_STATE=exc
#"OLDPWD" for cd - wise operation (default null)
DIRSTACK_OLDPWD=
#Include header
DIRSTACK_HEADER=false



#Insert into dir stack checking for repetitions
# $1 force (boolean)
# $2 path
add_dir_stack() { 
    local dir="$(realpath -P "${2:-"."}" 2>/dev/null)"
    [[ -d $dir ]] || { echo "Dir $dir not found";return; }
    # If executed del_dir_stack and keep working in it...
    [[ $1 == false && $_DIR_STACK_LDIR == $dir ]] && return
    _DIR_STACK_LDIR=$dir

    # Push $DIRSTACK_OLDPWD 
    push_dir_stack() {
        local dir=$1
        local msg=$2
        #Check duplicates
        readarray -t dup <<<"$(dirs -p -l 2>/dev/null)"
        #First entry (0) is always $PWD
        dup=${dup[@]:1}
        for elem in "${dup[@]}"; do [[ $elem = $dir ]]&& { return; } done
        #Check limit
        (( ${#dup[@]} > $DIRSTACK_LIMIT )) && del_dir_stack $DIRSTACK_LIMIT silent  
        pushd -n "$dir" >/dev/null 
        [[ $? == 0 && $msg == true ]] && echo Added "$dir" to dir stack
    }

    #Don't register $DIRSTACK_OLDPWD into dir stack till lost from cd - (OLDPWD)
    # FSM of two states
    # exc -> new = push old if allowed. set $DIRSTACK_OLDPWD = $dir
    # new -> new = push old if allowed. set $DIRSTACK_OLDPWD = $OLDPWD
    # exc -> exc = push old. set $DIRSTACK_OLDPWD = 
    # new -> exc = push old. set $DIRSTACK_OLDPWD = OLDPWD
    # $1 force (boolean)
    # $2 path
    push_old_dir_stack() {
        local dir=$2
        #If force
        if [[ $1 == true ]]; then
            push_dir_stack "$dir" true
        else
            #exc -> new
            if  [[ $DIRSTACK_STATE == exc ]]; then
                if [[ -n $DIRSTACK_OLDPWD && $DIRSTACK_OLDPWD != $dir ]]; then 
                    push_dir_stack "$DIRSTACK_OLDPWD"
                fi
                DIRSTACK_OLDPWD=$dir
            else #new -> new 
                if [[ $DIRSTACK_OLDPWD != $OLDPWD && $DIRSTACK_OLDPWD != $dir ]]; then
                    push_dir_stack "$DIRSTACK_OLDPWD"
                fi
                DIRSTACK_OLDPWD=$OLDPWD
            fi

            DIRSTACK_STATE=new
        fi
    }

    #Set exclusions
    IFS=":"; excl=($DIRSTACK_EXCLUDE); unset IFS
    #Check exclusions
    for elem in "${excl[@]}"; do 
        if [[ $elem = $dir ]]; then
            # $DIRSTACK_STATE - > exc  (two events of the FSM, see push_old_dir_stack)
            if [[ -n $DIRSTACK_OLDPWD ]]; then
                #Don't be wise and push it!
                [[ $DIRSTACK_OLDPWD != $OLDPWD ]] && push_dir_stack "$DIRSTACK_OLDPWD"
                [[ $DIRSTACK_STATE = exc ]] && DIRSTACK_OLDPWD=  || DIRSTACK_OLDPWD=$OLDPWD
            fi
            DIRSTACK_STATE=exc
            return
        fi
    done

    #Be savvy with the stack dirs then
    push_old_dir_stack $1 "$dir"
}


#Delete dir stack whithout changing dir
del_dir_stack () { 
    local -A dirs 
    local -a entries
    local dest= dir= del= num
    #if no args then $@=x actual
    (( $# == 0 )) && set -- x actual

    for args; do
        [[ $args = actual || $args == 0 || $args == silent ]] && break
        #if the user wants to delete actual dir
        if [[ $args = . ]]; then
            dir=$(realpath -P "." 2>/dev/null)
            #Discard first entry cause it's always $PWD
            readarray -s 1 -t entries <<<"$(dirs -p -l 2>/dev/null)"
            for i in ${!entries[@]}; do [[ ${entries[$i]} = $dir ]] && dirs["$dir"]=del; done
            # check if you actually want to delete current dir (no args)
            (( ${#dirs[@]} == 0 )) && { echo "PWD not in dir stack"; return; }
        else
            dest=$(dirs -l +$args 2>/dev/null)
            [[ -z $dest ]] && { echo "Incorrect dir stack index ($args) or empty stack";return; }
            #dir=$(realpath -P "$dest" 2>/dev/null)
            #not able to get the realpath so the user passed a deleted dir 
            dirs["$dest"]=del
        fi
    done

    for key in "${!dirs[@]}"; do
        del=$key
        #Discard first entry cause it's always $PWD
        readarray -s 1 -t entries <<<"$(dirs -p -l 2>/dev/null)"
        for i in "${!entries[@]}"; do 
            if [[ ${entries[$i]} = $del ]]; then
                popd -n +$((i+1)) >/dev/null; 
                [[ $? == 0 && $2 != silent ]] && echo Deleted "$del" from dir stack
            fi
        done
    done
}

#Go to a dir stack number. 
go_dir_stack() { 
    #Get absolute path
    local dir="$(dirs -l +$1 2>/dev/null)"
    [[ $dir ]] || { echo "Incorrect dir stack index or empty stack";return;}
    cd "$dir" && echo Changed dir to "$dir"
}

#Show the dir stack below the bash prompt
list_dir_stack() {
    [[ ${DIRSTACK_ENABLED} != true ]] && return
    local cwd="$(pwd -P)"
    add_dir_stack false "$cwd"

    local -a entries
    local Orange='\e[00;33m'
    local back='\e[00;44m'
    local deleted='\e[00;41m'
    local Reset='\e[00m'
    local Green='\e[01;32m'
    #Copy & Paste from any unicode table... 
    local one=$(printf "%s" ✪)
    local two=$(printf "%s" ✪)
    local i=0 
    local opwd="$(realpath -P "$OLDPWD" 2>/dev/null)"
    local OLD=${opwd/$HOME/\~}
    (( ${#OLD} > 20 )) && OLD=...${OLD: -20}
    [[ -n $OLD ]] && OLD="(P:$OLD)"
    
    if [[ $DIRSTACK_HEADER == true ]]; then
        echo -e "${Green}${one} $USER$(__git_ps1 "(%s)") on $TTY@$HOSTNAME($KERNEL)"
    fi
    echo -ne "${Green}${two} ${Orange}"

    #Discard first entry cause it's always $PWD
    readarray -s 1 -t entries <<<"$(dirs -p -l 2>/dev/null)"
    for i in ${!entries[@]}; do 
        (($i == 0)) && echo -ne "$OLD"
        dir=${entries[$i]} 
        #Show deleted on red
        if [[ ! -e $dir ]]; then #Put background color
            echo -ne "[${deleted}$((i+1)):${dir/$HOME/\~}${Orange}]";
        elif [[ $dir == $cwd ]]; then #Put background color
            echo -ne "[${back}$((i+1)):${dir/$HOME/\~}${Orange}]";
        else
            echo -ne "[$((i+1)):${dir/$HOME/\~}]";
        fi
    done
    (( ${#entries[@]} == 0 )) && echo -ne "$OLD Empty dir stack(a add,d delete,g go number,~num = dir)";

    #Print newline for PS1
    echo -e "${Reset}"
}

#Seek forward and change dir in your current path an expresion
go_forward() {
    [[ ${DIRSTACK_ENABLED} != true ]] && return
    local cwd="$(pwd -P)" dir=
    [[ $1 ]] || { echo "You need to pass at least an argument"; return 1; }
    local dest='.*'
    for arg; do dest+="$arg.*"; done
    local -a entries
   
    #Read entries
    readarray -t entries <<<"$(dirs -p -l 2>/dev/null)"
    for i in ${!entries[@]}; do 
        dir=${entries[$i]} 

        #Not deleted dir
        if [[ -e $dir &&  $dir =~ $cwd/$dest ]]; then 
            #echo "$dir is a match for $dest"
            cd $dir
            return 0;
        fi
    done
    return 1;
}

#Seek backward and change dir in your current path an expresion
go_backward() {
    [[ ${DIRSTACK_ENABLED} != true ]] && return
    local cwd="$(pwd -P)" dir=
    [[ $1 ]] || { echo "You need to pass at least an argument"; return 1; }
    local dest='.*'
    for arg; do dest+="$arg.*"; done
    local -a entries
   
    #Read entries
    readarray -t entries <<<"$(dirs -p -l 2>/dev/null)"
    for i in ${!entries[@]}; do 
        dir=${entries[$i]} 

        #Not deleted dir
        if [[ -e $dir && $cwd == $dir/* &&  $dir =~ .*$dest.* ]]; then
            #echo "$dir is a match for $dest"
            cd $dir
            return 0;
        fi
    done
    return 1;
}


# If enabled load aliases
if [[ $DIRSTACK_ENABLED == true ]]; then
    [ -v DIRSTACK_LIMIT ] || echo DIRSTACK_LIMIT must be a number
    [ -v DIRSTACK_EXCLUDE ] || echo DIRSTACK_EXCLUDE must be a string
    alias a="add_dir_stack true"
    alias d=del_dir_stack
    alias g=go_dir_stack
    alias gf=go_forward 
    alias gb=go_backward
    PROMPT_COMMAND+=';list_dir_stack'
fi

