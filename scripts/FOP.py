#!/usr/bin/env python3

# Import the key modules
import collections
import filecmp
import os
import re
import subprocess
import sys
# Import a module only available in Python 3
from urllib.parse import urlparse

""" FOP
    Filter Orderer and Preener
    Copyright (C) 2011 Michael
    Fixed by LanikSJ 2021-09-06

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program. If not, see <https://www.gnu.org/licenses/>."""

# FOP version number
VERSION = 3.9

# Check the version of Python for language compatibility and subprocess.check_output()
MAJOR_REQUIRED = 3
MINOR_REQUIRED = 1
if sys.version_info < (MAJOR_REQUIRED, MINOR_REQUIRED):
    raise RuntimeError("FOP requires Python {reqmajor}.{reqminor} or greater, but Python {ismajor}.{isminor} is being "
                       "used to run this program.".format(reqmajor=MAJOR_REQUIRED, reqminor=MINOR_REQUIRED,
                                                          ismajor=sys.version_info.major,
                                                          isminor=sys.version_info.minor))

# Compile regular expressions to match important filter parts (derived from Wladimir Palant's Adblock Plus source code)
ELEMENT_DOMAIN_PATTERN = re.compile(r"^([^/*|@\"!]*?)#@?#")
FILTER_DOMAIN_PATTERN = re.compile(r"(?:$|,)domain=([^,\s]+)$")
ELEMENT_PATTERN = re.compile(r"^([^/*|@\"!]*?)(#@?#?)([^{}]+)$")
OPTION_PATTERN = re.compile(r"^(.*)\$(~?[\w\-]+(?:=[^,\s]+)?(?:,~?[\w\-]+(?:=[^,\s]+)?)*)$")

# Compile regular expressions that match element tags and pseudo classes and strings and tree selectors; "@"
# indicates either the beginning or the end of a selector
SELECTOR_PATTERN = re.compile(
    r"(?<=[\s\[@])([a-zA-Z]*[A-Z][a-zA-Z0-9]*)((?=([\[\]^*$=:@#.]))|(?=(\s(?:[+>~]|\*|[a-zA-Z][a-zA-Z0-9]*[\["
    r":@\s#.]|[#.][a-zA-Z][a-zA-Z0-9]*))))")
PSEUDO_PATTERN = re.compile(r"(:[a-zA-Z\-]*[A-Z][a-zA-Z\-]*)(?=([(:@\s]))")
REMOVAL_PATTERN = re.compile(r"((?<=([>+~,]\s))|(?<=(@|\s|,)))(\*)(?=([#.\[:]))")
ATTRIBUTE_VALUE_PATTERN = re.compile(r"^([^\'\"\\]|\\.)*(\"(?:[^\"\\]|\\.)*\"|\'(?:[^\'\\]|\\.)*\')|\*")
TREE_SELECTOR = re.compile(r"(\\.|[^+>~\\ \t])\s*([+>~ \t])\s*(\D)")
UNICODE_SELECTOR = re.compile(r"\\[0-9a-fA-F]{1,6}\s[a-zA-Z]*[A-Z]")
# Remove any bad lines less the 3 chars, starting with.. |*~@$%
BAD_LINE = re.compile(r"^([|*~@$%].{1,3}$)")

# Compile a regular expression that describes a completely blank line
BLANK_PATTERN = re.compile(r"^\s*$")

# Compile a regular expression that validates commit comments
COMMIT_PATTERN = re.compile(r"^([AMP]):\s(\((.+)\)\s)?(.*)$")

# List the files that should not be sorted, either because they have a special sorting system or because they are not
# filter files
IGNORE = ("CC-BY-SA.txt", "easytest.txt", "GPL.txt", "MPL.txt",
          "enhancedstats-addon.txt", "fanboy-tracking", "firefox-regional", "other",
          "easylist_cookie_specific_uBO.txt", "fanboy_annoyance_specific_uBO.txt",
          "fanboy_notifications_specific_uBO.txt", "fanboy_social_specific_uBO.txt")

# List all Adblock Plus options (excepting domain, which is handled separately), as of version 1.3.9
KNOWN_OPTIONS = ("collapse", "csp", "document", "elemhide",
                 "font", "genericblock", "generichide", "image", "match-case",
                 "object", "media", "object-subrequest", "other", "ping", "popup",
                 "rewrite=abp-resource:blank-css", "rewrite=abp-resource:blank-js", "rewrite=abp-resource:blank-html",
                 "rewrite=abp-resource:blank-mp3", "rewrite=abp-resource:blank-text",
                 "rewrite=abp-resource:1x1-transparent-gif", "rewrite=abp-resource:2x2-transparent-png",
                 "rewrite=abp-resource:3x2-transparent-png", "rewrite=abp-resource:32x32-transparent-png",
                 "script", "stylesheet", "subdocument", "third-party", "websocket", "webrtc", "xmlhttprequest")

# List the supported revision control system commands
REPODEF = collections.namedtuple("repodef",
                                 "name, directory, locationoption, repodirectoryoption, checkchanges, difference, "
                                 "commit, pull, push")
GIT = REPODEF(["git"], "./.git/", "--work-tree=", "--git-dir=", ["status", "-s", "--untracked-files=no"], ["diff"],
              ["commit", "-a", "-m"], ["pull"], ["push"])
HG = REPODEF(["hg"], "./.hg/", "-R", None, ["stat", "-q"], ["diff"], ["commit", "-m"], ["pull"], ["push"])
REPO_TYPES = (GIT, HG)


def start():
    """ Print a greeting message and run FOP in the directories
    specified via the command line, or the current working directory if
    no arguments have been passed."""
    greeting = "FOP (Filter Orderer and Preener) version {version}".format(version=VERSION)
    characters = len(str(greeting))
    print("=" * characters)
    print(greeting)
    print("=" * characters)

    # Convert the directory names to absolute references and visit each unique location
    places = sys.argv[1:]
    if places:
        places = [os.path.abspath(place) for place in places]
        for place in sorted(set(places)):
            main(place)
            print()
    else:
        main(os.getcwd())


def main(location):
    """ Find and sort all the files in a given directory, committing
    changes to a repository if one exists."""
    # Check that the directory exists, otherwise return
    command = 0
    basecommand = 0
    original_difference = 0
    if not os.path.isdir(location):
        print("{location} does not exist or is not a folder.".format(location=location))
        return

    # Set the repository type based on hidden directories
    repository = None
    for repo_type in REPO_TYPES:
        if os.path.isdir(os.path.join(location, repo_type.directory)):
            repository = repo_type
            break
    # If this is a repository, record the initial changes; if this fails, give up trying to use the repository
    if repository:
        try:
            basecommand = repository.name
            if repository.locationoption.endswith("="):
                basecommand.append(
                    "{locationoption}{location}".format(locationoption=repository.locationoption, location=location))
            else:
                basecommand.extend([repository.locationoption, location])
            if repository.repodirectoryoption:
                if repository.repodirectoryoption.endswith("="):
                    basecommand.append(
                        "{repodirectoryoption}{location}".format(repodirectoryoption=repository.repodirectoryoption,
                                                                 location=os.path.normpath(
                                                                     os.path.join(location, repository.directory))))
                else:
                    basecommand.extend([repository.repodirectoryoption, location])
            command = basecommand + repository.checkchanges
            original_difference = True if subprocess.check_output(command) else False
        except(subprocess.CalledProcessError, OSError):
            print(
                "The command \"{command}\" was unable to run; FOP will therefore not attempt to use the repository "
                "tools. On Windows, this may be an indication that you do not have sufficient privileges to run FOP - "
                "the exact reason why is unknown. Please also ensure that your revision control system is installed "
                "correctly and understood by FOP.".format(
                    command=" ".join(command)))
            repository = None

    # Work through the directory and any subdirectories, ignoring hidden directories
    print("\nPrimary location: {folder}".format(folder=os.path.join(os.path.abspath(location), "")))
    for path, directories, files in os.walk(location):
        for direct in directories[:]:
            if direct.startswith(".") or direct in IGNORE:
                directories.remove(direct)
        print("Current directory: {folder}".format(folder=os.path.join(os.path.abspath(path), "")))
        directories.sort()
        for filename in sorted(files):
            address = os.path.join(path, filename)
            extension = os.path.splitext(filename)[1]
            # Sort all text files that are not blacklisted
            if extension == ".txt" and filename not in IGNORE:
                fop_sort(address)
            # Delete unnecessary backups and temporary files
            if extension == ".orig" or extension == ".temp":
                try:
                    os.remove(address)
                except(IOError, OSError):
                    # Ignore errors resulting from deleting files, as they likely indicate that the file has already
                    # been deleted
                    pass

    # If in a repository, offer to commit any changes
    if repository:
        commit(repository, basecommand, original_difference)


def fop_sort(filename):
    """ Sort the sections of the file and save any modifications."""
    temporary_file = "{filename}.temp".format(filename=filename)
    checkline = 10
    section = []
    lines_checked = 1
    filter_lines = element_lines = 0

    # Read in the input and output files concurrently to allow filters to be saved as soon as they are finished with
    with open(filename, "r", encoding="utf-8", newline="\n") as input_file, open(temporary_file, "w", encoding="utf-8",
                                                                                 newline="\n") as output_file:

        # Combines domains for (further) identical rules
        def combine_filters(uncombined_filters, domain_pattern, domain_separator):
            domains2 = 0
            domain1str = 0
            combined_filters = []
            for i in range(len(uncombined_filters)):
                domains1 = re.search(domain_pattern, uncombined_filters[i])
                if i + 1 < len(uncombined_filters) and domains1:
                    domains2 = re.search(domain_pattern, uncombined_filters[i + 1])
                    domain1str = domains1.group(1)

                if not domains1 or i + 1 == len(uncombined_filters) or not domains2 or len(domain1str) == 0 or len(
                        domains2.group(1)) == 0:
                    # last filter or filter didn't match regex or no domains
                    combined_filters.append(uncombined_filters[i])
                else:
                    domain2str = domains2.group(1)
                    if domains1.group(0).replace(domain1str, domain2str, 1) != domains2.group(0):
                        # non-identical filters shouldn't be combined
                        combined_filters.append(uncombined_filters[i])
                    elif re.sub(domain_pattern, "", uncombined_filters[i]) == re.sub(domain_pattern, "",
                                                                                     uncombined_filters[i + 1]):
                        # identical filters. Try to combine them...
                        new_domains = "{d1}{sep}{d2}".format(d1=domain1str, sep=domain_separator, d2=domain2str)
                        new_domains = domain_separator.join(
                            sorted(set(new_domains.split(domain_separator)), key=lambda domain: domain.strip("~")))
                        if (domain1str.count("~") != domain1str.count(domain_separator) + 1) != (
                                domain2str.count("~") != domain2str.count(domain_separator) + 1):
                            # do not combine rules containing included domains with rules containing only excluded
                            # domains
                            combined_filters.append(uncombined_filters[i])
                        else:
                            # either both contain one or more included domains, or both contain only excluded domains
                            domains_substitute = domains1.group(0).replace(domain1str, new_domains, 1)
                            uncombined_filters[i + 1] = re.sub(domain_pattern, domains_substitute,
                                                               uncombined_filters[i])
                    else:
                        # non-identical filters shouldn't be combined
                        combined_filters.append(uncombined_filters[i])
            return combined_filters

        # Writes the filter lines to the file
        def write_filters():
            if element_lines > filter_lines:
                uncombined_filters = sorted(set(section), key=lambda rule: re.sub(ELEMENT_DOMAIN_PATTERN, "", rule))
                output_file.write("{filters}\n".format(
                    filters="\n".join(combine_filters(uncombined_filters, ELEMENT_DOMAIN_PATTERN, ","))))
            else:
                uncombined_filters = sorted(set(section), key=str.lower)
                output_file.write("{filters}\n".format(
                    filters="\n".join(combine_filters(uncombined_filters, FILTER_DOMAIN_PATTERN, "|"))))

        for line in input_file:
            line = line.strip()
            if not re.match(BLANK_PATTERN, line):
                # Include comments verbatim and, if applicable, sort the preceding section of filters and save them
                # in the new version of the file
                if line[0] == "!" or line[:8] == "%include" or line[0] == "[" and line[-1] == "]":
                    if section:
                        write_filters()
                        section = []
                        lines_checked = 1
                        filter_lines = element_lines = 0
                    output_file.write("{line}\n".format(line=line))
                else:
                    # Skip filters containing less than three characters
                    if len(line) < 3:
                        continue
                    # Neaten up filters and, if necessary, check their type for the sorting algorithm
                    element_parts = re.match(ELEMENT_PATTERN, line)
                    if element_parts:
                        domains = element_parts.group(1).lower()
                        if lines_checked <= checkline:
                            element_lines += 1
                            lines_checked += 1
                        line = element_tidy(domains, element_parts.group(2), element_parts.group(3))
                    else:
                        if lines_checked <= checkline:
                            filter_lines += 1
                            lines_checked += 1
                        line = filter_tidy(line)
                    # Add the filter to the section
                    section.append(line)
        # At the end of the file, sort and save any remaining filters
        if section:
            write_filters()

    # Replace the existing file with the new one only if alterations have been made
    if not filecmp.cmp(temporary_file, filename):
        # Check the operating system and, if it is Windows, delete the old file to avoid an exception (it is not
        # possible to rename files to names already in use on this operating system)
        if os.name == "nt":
            os.remove(filename)
        os.rename(temporary_file, filename)
        print("Sorted: {filename}".format(filename=os.path.abspath(filename)))
    else:
        os.remove(temporary_file)


def filter_tidy(filtering):
    """ Sort the options of blocking filters and make the filter text
    lower case if applicable."""
    option_split = re.match(OPTION_PATTERN, filtering)

    if not option_split:
        # Remove unnecessary asterisks from filters without any options and return them
        return remove_unnecessary_wildcards(filtering)
    else:
        # If applicable, separate and sort the filter options in addition to the filter text
        filter_text = remove_unnecessary_wildcards(option_split.group(1))
        option_list = option_split.group(2).lower().replace("_", "-").split(",")

        domain_list = []
        remove_entries = []
        for option in option_list:
            # Detect and separate domain options
            if option[0:7] == "domain=":
                domain_list.extend(option[7:].split("|"))
                remove_entries.append(option)
            elif option.strip("~") not in KNOWN_OPTIONS:
                print(
                    f'Warning: The option "{option}" used on the filter "{filtering}" is not recognised by FOP')
        # Sort all options other than domain alphabetically For identical options, the inverse always follows the
        # non-inverse option ($image,~image instead of $~image,image)
        option_list = sorted(set(filter(lambda options: options not in remove_entries, option_list)),
                             key=lambda options: (options[1:] + "~") if options[0] == "~" else options)
        # If applicable, sort domain restrictions and append them to the list of options
        if domain_list:
            option_list.append("domain={domainlist}".format(domainlist="|".join(
                sorted(set(filter(lambda domain: domain != "", domain_list)), key=lambda domain: domain.strip("~")))))

        # Return the full filter
        return "{filtertext}${options}".format(filtertext=filter_text, options=",".join(option_list))


def element_tidy(domains, separator, selector):
    """ Sort the domains of element hiding rules, remove unnecessary
    tags and make the relevant sections of the rule lower case."""
    # Order domain names alphabetically, ignoring exceptions
    if "," in domains:
        domains = ",".join(sorted(set(domains.split(",")), key=lambda domain: domain.strip("~")))
    # Mark the beginning and end of the selector with "@"
    selector = "@{selector}@".format(selector=selector)
    each = re.finditer
    # Make sure we don't match items in strings (e.g., don't touch Width in ##[style="height:1px; Width: 123px;"])
    selector_without_strings = selector
    selector_only_strings = ""
    while True:
        string_match = re.match(ATTRIBUTE_VALUE_PATTERN, selector_without_strings)
        if string_match is None:
            break
        selector_without_strings = selector_without_strings.replace(
            "{before}{stringpart}".format(before=string_match.group(1), stringpart=string_match.group(2)),
            "{before}".format(before=string_match.group(1)), 1)
        selector_only_strings = "{old}{new}".format(old=selector_only_strings, new=string_match.group(2))
    # Clean up tree selectors
    for tree in each(TREE_SELECTOR, selector):
        if tree.group(0) in selector_only_strings or not tree.group(0) in selector_without_strings:
            continue
        replace_by = " {g2} ".format(g2=tree.group(2))
        if replace_by == "   ":
            replace_by = " "
        selector = selector.replace(tree.group(0), "{g1}{replaceby}{g3}".format(g1=tree.group(1),
                                                                                replaceby=replace_by,
                                                                                g3=tree.group(3)), 1)
    # Remove unnecessary tags
    for untag in each(REMOVAL_PATTERN, selector):
        untag_name = untag.group(4)
        if not (not (untag_name in selector_only_strings) and untag_name in selector_without_strings):
            continue
        bc = untag.group(2)
        if bc is None:
            bc = untag.group(3)
        ac = untag.group(5)
        selector = selector.replace("{before}{untag}{after}".format(before=bc, untag=untag_name, after=ac),
                                    "{before}{after}".format(before=bc, after=ac), 1)
    # Make the remaining tags lower case wherever possible
    for tag in each(SELECTOR_PATTERN, selector):
        tag_name = tag.group(1)
        if tag_name in selector_only_strings and tag_name not in selector_without_strings:
            if re.search(UNICODE_SELECTOR, selector_without_strings) is None:
                ac = tag.group(3)
                if ac is None:
                    ac = tag.group(4)
                selector = selector.replace("{tag}{after}".format(tag=tag_name, after=ac),
                                            "{tag}{after}".format(tag=tag_name.lower(), after=ac), 1)
                continue
            break
    # Make pseudo classes lower case where possible
    for pseudo in each(PSEUDO_PATTERN, selector):
        pseudo_class = pseudo.group(1)
        if not (pseudo_class in selector_only_strings and not (pseudo_class in selector_without_strings)):
            continue
        ac = pseudo.group(3)
        selector = selector.replace("{pclass}{after}".format(pclass=pseudo_class, after=ac),
                                    "{pclass}{after}".format(pclass=pseudo_class.lower(), after=ac), 1)
    # Remove the markers from the beginning and end of the selector and return the complete rule
    return "{domain}{separator}{selector}".format(domain=domains, separator=separator, selector=selector[1:-1])


def commit(repository, base_command, user_changes):
    """ Commit changes to a repository using the commands provided."""
    commands = 0
    difference = subprocess.check_output(base_command + repository.difference)
    if not difference:
        print("\nNo changes have been recorded by the repository.")
        return
    print("\nThe following changes have been recorded by the repository:")
    try:
        print(difference.decode("utf-8"))
    except UnicodeEncodeError:
        print("\nERROR: DIFF CONTAINED UNKNOWN CHARACTER(S). Showing unformatted diff instead:\n")
        print(difference)

    try:
        # Persistently request a suitable comment
        while True:
            comment = input("Please enter a valid commit comment or quit:\n")
            if check_comment(comment, user_changes):
                break
    # Allow users to abort the commit process if they do not approve of the changes
    except (KeyboardInterrupt, SystemExit):
        print("\nCommit aborted.")
        return

    print("Comment \"{comment}\" accepted.".format(comment=comment))
    try:
        # Commit the changes
        commands = base_command + repository.commit + [comment]
        subprocess.Popen(commands).communicate()
        print("\nConnecting to server. Please enter your password if required.")
        # Update the server repository as required by the revision control system
        for commands in repository[7:]:
            commands = base_command + commands
            subprocess.Popen(commands).communicate()
            print()
    except subprocess.CalledProcessError:
        print(f"Unexpected error with the command \"{commands}\".")
        raise subprocess.CalledProcessError("Aborting FOP.")
    except OSError:
        print(f"Unexpected error with the command \"{commands}\".")
        raise OSError("Aborting FOP.")
    print("Completed commit process successfully.")


def is_global_element(domains):
    """ Check whether all domains are negations."""
    for domain in domains.split(","):
        if domain and not domain.startswith("~"):
            return False
    return True


def remove_unnecessary_wildcards(filtertext):
    """ Where possible, remove unnecessary wildcards from the beginnings
    and ends of blocking filters."""
    allow_list = False
    had_star = False
    if filtertext[0:2] == "@@":
        allow_list = True
        filtertext = filtertext[2:]
    while len(filtertext) > 1 and filtertext[0] == "*" and not filtertext[1] == "|" and not filtertext[1] == "!":
        filtertext = filtertext[1:]
        had_star = True
    while len(filtertext) > 1 and filtertext[-1] == "*" and not filtertext[-2] == "|" and not filtertext[-2] == " ":
        filtertext = filtertext[:-1]
        had_star = True
    if had_star and filtertext[0] == "/" and filtertext[-1] == "/":
        filtertext = "{filtertext}*".format(filtertext=filtertext)
    if filtertext == "*":
        filtertext = ""
    if allow_list:
        filtertext = "@@{filtertext}".format(filtertext=filtertext)
    return filtertext


def check_comment(comment, changed):
    """ Check the commit comment and return True if the comment is
    acceptable and False if it is not."""
    sections = re.match(COMMIT_PATTERN, comment)
    if sections is None:
        print(f"The comment \"{comment}\" is not in the recognised format.")
    else:
        indicator = sections.group(1)
        if indicator == "M":
            # Allow modification comments to have practically any format
            return True
        elif indicator == "A" or indicator == "P":
            if not changed:
                print(
                    "You have indicated that you have added or removed a rule, but no changes were initially noted by "
                    "the repository.")
            else:
                address = sections.group(4)
                if not valid_url(address):
                    print("Unrecognised address \"{address}\".".format(address=address))
                else:
                    # The user has changed the subscription and has written a suitable comment
                    # message with a valid address
                    return True
    print()
    return False


def valid_url(url):
    """ Check that an address has a scheme (e.g. http), a domain name
    (e.g. example.com) and a path (e.g. /), or relates to the internal
    about system."""
    address_part = urlparse(url)
    if address_part.scheme and address_part.netloc and address_part.path:
        return True
    elif address_part.scheme == "about":
        return True
    else:
        return False


if __name__ == '__main__':
    start()
