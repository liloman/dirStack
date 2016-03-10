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
DIRSTACK_STATE="exc"
#"OLDPWD" for cd - wise operation (default null)
DIRSTACK_OLDPWD=



#Insert into dir stack checking for repetitions
# $1 force (boolean)
# $2 path
add_dir_stack() { 
    local dir="$(realpath -P "${2:-"."}" 2>/dev/null)"
    [[ -d $dir ]] || { echo "Dir $dir not found";return; }
    # If executed del_dir_stack and keep working in it...
    [[ $1 == false && $_DIR_STACK_LDIR == $dir ]] && return
    _DIR_STACK_LDIR="$dir"

    # Push $DIRSTACK_OLDPWD 
    push_dir_stack() {
        local dir="$1"
        #Check duplicates
        readarray -t dup <<<"$(dirs -p -l 2>/dev/null)"
        #First entry (0) is always $PWD
        dup=${dup[@]:1}
        for elem in "${dup[@]}"; do [[ $elem = $dir ]]&& { return; } done
        #Check limit
        (( ${#dup[@]} > $DIRSTACK_LIMIT )) && del_dir_stack $DIRSTACK_LIMIT silent  
        pushd -n "$dir" >/dev/null; 
    }

    #Don't register $DIRSTACK_OLDPWD into dir stack till lost from cd - (OLDPWD)
    # FSM of two states
    # exc -> new = push old if allowed. set $DIRSTACK_OLDPWD = $dir
    # new -> new = push old if allowed. set $DIRSTACK_OLDPWD = $OLDPWD
    # exc -> exc = push old. set $DIRSTACK_OLDPWD = 
    # new -> exc = push old. set $DIRSTACK_OLDPWD = OLDPWD
    push_old_dir_stack() {
        local dir="$1"
        #exc -> new
        if  [[ $DIRSTACK_STATE == exc ]]; then
            if [[ -n $DIRSTACK_OLDPWD && $DIRSTACK_OLDPWD != $dir ]]; then 
                push_dir_stack "$DIRSTACK_OLDPWD"
            fi
            DIRSTACK_OLDPWD="$dir"
        else #new -> new 
            if [[ $DIRSTACK_OLDPWD != $OLDPWD && $DIRSTACK_OLDPWD != $dir ]]; then
                push_dir_stack "$DIRSTACK_OLDPWD"
            fi
            DIRSTACK_OLDPWD="$OLDPWD"
        fi

        DIRSTACK_STATE="new"
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
            DIRSTACK_STATE="exc"
            return
        fi
    done

    #Be savvy with the stack dirs then
    push_old_dir_stack "$dir"
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
        if [[ $args = x ]]; then
            dir=$(realpath -P "." 2>/dev/null)
            #Discard first entry cause it's always $PWD
            readarray -s 1 -t entries <<<"$(dirs -p -l 2>/dev/null)"
            for i in ${!entries[@]}; do [[ ${entries[$i]} = $dir ]] && dirs["$dir"]=del; done
            # check if you actually want to delete current dir (no args)
            (( ${#dirs[@]} == 0 )) && { echo "PWD not in dir stack"; return; }
        else
            dest=$(dirs -l +$args 2>/dev/null)
            dir=$(realpath -P "$dest" 2>/dev/null)
            [[ $dir ]] || { echo "Incorrect dir stack index ($args) or empty stack";return; }
            dirs["$dir"]=del
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
        local Reset='\e[00m'
        local Green='\e[01;32m'
        #Copy & Paste from any unicode table... 
        local one=$(printf "%s" ✪)
        local two=$(printf "%s" ✪)
        local i=0 

        echo -e "${Green}${one} $USER$(__git_ps1 "(%s)") on $TTY@$HOSTNAME($KERNEL)"
        echo -ne "${Orange}${two} "

        #Discard first entry cause it's always $PWD
        readarray -s 1 -t entries <<<"$(dirs -p -l 2>/dev/null)"
        for i in ${!entries[@]}; do 
            dir=${entries[$i]} 
            if [[ $dir == $cwd ]]; then #Put background color
                echo -ne "[${back}$((i+1)):${dir/$HOME/\~}${Orange}]";
            else
                echo -ne "[$((i+1)):${dir/$HOME/\~}]";
            fi
        done
        (( ${#entries[@]} == 0 )) && echo -ne "${two} ${Orange}Empty dir stack(a add,d delete,g go number,~num = dir)";

        #Print newline for PS1
        echo -e "${Reset}"
    }


    # If enabled load aliases
    if [[ $DIRSTACK_ENABLED == true ]]; then
        [ -v DIRSTACK_LIMIT ] || echo DIRSTACK_LIMIT must be a number
        [ -v DIRSTACK_EXCLUDE ] || echo DIRSTACK_EXCLUDE must be a string
        alias a="add_dir_stack true"
        alias d=del_dir_stack
        alias g=go_dir_stack
        PROMPT_COMMAND+=';list_dir_stack'
    fi

