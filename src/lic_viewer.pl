#!/usr/bin/perl
#-------------------------------------------------------------------------------
# 05/08/2023 - Initial draft
#-------------------------------------------------------------------------------
# Licensing under MIT license which allow for freely modify and distribution
#-------------------------------------------------------------------------------

use strict;
use warnings;
use CGI;

use Data::Dumper;
use Enmac::RDBMS;

#-------------------------------------------------------------------------------
# Function : render_html - Render CGI html
#-------------------------------------------------------------------------------
sub render_html{
    
    my $cgi = shift;
    my $comp_classes = shift;
    my $menus = shift;
    my $svg = shift;
    my $from_state = shift;
    my $to_state = shift;
    my $lic_and_aad = shift;

    # Print the HTTP header
    print $cgi->header;

    # Print the HTML content
    print <<HTML;
<!DOCTYPE html>
<html>
<head>
  <title>ADMS Life Cycle Viewer</title>
  <style>
    body {
      font-family: Arial, sans-serif;
      margin: 0;
      padding: 0;
    }

    header {
      background-color: #333;
      color: #fff;
      padding: 10px;
      text-align: center;
    }

    .container {
      display: flex;
      justify-content: space-between;
      padding: 20px;
    }

    .left-frame {
      width: 300px;
      background-color: #f0f0f0;
      padding: 10px;
      border-radius: 10px;
      box-shadow: 0 0 10px rgba(0, 0, 0, 0.1);
    }

    .right-frame {
      width: 85%;
      background-color: #fff;
      padding: 10px;
      border-radius: 10px;
      box-shadow: 0 0 10px rgba(0, 0, 0, 0.1);
    }

    select, input {
      display: block;
      margin-bottom: 10px;
      padding: 8px;
      width: 100%;
      border: 1px solid #ccc;
      border-radius: 5px;
    }

    button {
      background-color: #007bff;
      color: #fff;
      border: none;
      border-radius: 5px;
      padding: 10px 20px;
      cursor: pointer;
    }

    button:hover {
      background-color: #0056b3;
    }

    .detail-div {
      text-align: center;
      color: blue;
      font-size: 30px;
    }
  </style>
</head>
<body>
  <header>
    <h1>ADMS Life Cycle Viewer</h1>
  </header>
  <div class="detail-div">$lic_and_aad</div>
  <div class="container">
    <div class="left-frame">
      <label for="ccd_dropdown">Component Class:</label>
      <select id="ccd_dropdown">
HTML
    print "$comp_classes\n";
    print <<HTML;
      </select>
        <label for="mnu_dropdown">Menu:</label>
      <select id="mnu_dropdown">
HTML
    print "$menus";
    print <<HTML;
      </select>
      <label for="from_state_input">From State:</label>
      <input id="from_state_input" type="text" placeholder="State filter using regular expression" value="$from_state">
      <label for="to_state_input">To State:</label>
      <input id="to_state_input" type="text" placeholder="State filter using regular expression" value="$to_state" >
      <button id="generateBtn" onclick="generateClicked()">Generate Life Cycle</button>
    </div>
    <div class="right-frame">
HTML
    print($svg);
    print <<HTML;
    </div>
  </div>
  <script>
    // JavaScript function to handle the Generate button click event
    function generateClicked() {
      var selectedOption1 = document.getElementById('ccd_dropdown').value;

     // var selectedOption2 = document.getElementById('mnu_dropdown').selectedIndex;
      var dropdown2 = document.getElementById('mnu_dropdown');
      var selectedOption2 = dropdown2.options[dropdown2.selectedIndex].value;

      var fromState = document.getElementById('from_state_input').value;
      var toState = document.getElementById('to_state_input').value;

      // Update the URL parameters based on the selected values and reload the page
      var newURL = window.location.origin + window.location.pathname + '?ccd=' + selectedOption1 + '&menu=' + selectedOption2 + '&fromState=' + encodeURIComponent(fromState) + '&toState=' + encodeURIComponent(toState);
      window.location.href = newURL;
    }
  </script>
</body>
</html>
HTML
}

#-------------------------------------------------------------------------------
# Function : fetch_menu_items - return an array of menu names
#-------------------------------------------------------------------------------
sub fetch_menu_items{
    my $rdbms = shift;
    my @menus = ();
    my $sql=q{
select distinct
    menu_name, menu_name
FROM
    menu_definitions
ORDER BY 1
};
    my $sth = $rdbms->prepare($sql);
    $sth->execute();
    while (my @row = $sth->fetchrow_array) {
        push(@menus, \@row)
    }
    return @menus;
}

#-------------------------------------------------------------------------------
# Function : fetch_component_class_defn - return an array of component_class_defn
#-------------------------------------------------------------------------------
sub fetch_component_class_defn{
        my $rdbms = shift;
    my @ccd = ();
    my $sql=q{
SELECT
    component_class_index,
    component_class_name
FROM
    component_class_defn ccd
WHERE
    component_life_cycle IS NOT NULL
ORDER BY 2, 1
};
    my $sth = $rdbms->prepare($sql);
    $sth->execute();
    while (my @row = $sth->fetchrow_array) {
        push(@ccd, \@row)
    }
    return @ccd;

}

#-------------------------------------------------------------------------------
# Function : fetch_lic_and_aad_from_ccd - get the life cycle and appearance
# from component_class_defn
#-------------------------------------------------------------------------------
sub fetch_lic_and_aad_from_ccd{
    my $rdbms = shift;
    my $ccd_idx = shift;
    my $sql = q{
select component_life_cycle, component_appearance from component_class_defn ccd
where COMPONENT_CLASS_INDEX = ?
};
    my $sth = $rdbms->prepare($sql);
    $sth->execute($ccd_idx);
    my @row = $sth->fetchrow_array;
    return "<b>Life Cycle:</b>$row[0], <b>Appearance:</b>$row[1]";
}

#-------------------------------------------------------------------------------
# Function : convert_arrayref_to_html_selection - convert an aref to html drop list
# selection
#-------------------------------------------------------------------------------
sub convert_arrayref_to_html_selection{
    my $aref = shift;
    my $selected_item = shift;
    my $txt = '';
    for my $row (@{$aref}){
        my ($idx, $sel) = @$row;
        my $selected_txt='';
        if ("$selected_item" eq "$idx"){
            $selected_txt = ' selected="selected"';
        }
        $txt .= qq(<option value="$idx"$selected_txt>$sel</option>);
        $txt .= "\n";
    }
    return $txt;
}

#-------------------------------------------------------------------------------
# Function : fetch_lic_for_graphviz - Get a list of array txt for graphviz
#-------------------------------------------------------------------------------
sub fetch_lic_for_graphviz{
    my $sql=q~
    with menus as (
      select * from menu_definitions 
        start with menu_name= ?
        connect by prior SUB_MENU = menu_name
    ), actions as (
      select menu_name||'\n'||ITEM_NAME as ITEM_NAME, 
        DATA as action_name 
        from menus 
        where FUNCTION like 'CREATE_OP_FROM_ACTION_%'
        and Status =0
    ), 
    appearances as (
      select * from (
          select ROW_NUMBER() 
            OVER( PARTITION BY displayed_state order by state) as row_num, 
          displayed_state, state, 
          replace(displayed_state|| ' (' ||state || ')', ' ', ' ') as display_state_num 
          from action_appearances 
          where name in 
          (select component_appearance 
              from component_class_defn where component_class_index = ?)  
      ) where row_num =1
    ),
    comp_life_cycle as (
      select current_state, 
      replace(transition,' ','') as transition, 
      next_state from life_cycles 
      where name in 
      (select component_life_cycle 
          from component_class_defn 
          where COMPONENT_CLASS_INDEX = ?)
      and regexp_like(current_state, ?)
      and regexp_like(next_state, ?)
    ),
    menu_actions as (
        select a.ITEM_NAME, acd.action_name, 
        switch_mask || ',' || switch_value as transition 
        from action_definitions acd
        inner join actions a on acd.action_name = a.action_name
    )
    select '"' || nvl(a1.display_state_num, clc.current_state || '_ERROR') || '" -> "' || 
        nvl(a2.display_state_num, clc.next_state || '_ERROR') || 
        '" [ label="' || 
        ma.ITEM_NAME || '\n' || 
        clc.transition || '"];'
    from comp_life_cycle clc
    left join menu_actions ma  on clc.transition = ma.transition 
    left join appearances a1 on clc.current_state = a1.displayed_state
    left join appearances a2 on clc.next_state = a2.displayed_state
    order by 1
~;
    my $rdbms = shift;
    my $class_idx = shift;
    my $menu = shift;
    my $from_state = shift;
    $from_state = '.*' if !$from_state;
    my $to_state = shift;
    $to_state = '.*' if !$to_state;
    my $txt = '';
    my $sth = $rdbms->prepare($sql);
    $sth->execute($menu, $class_idx, $class_idx, $from_state, $to_state);
    while (my $row = $sth->fetchrow_array) {
        $txt .=$row."\n";
    }
    return $txt;
}

#-------------------------------------------------------------------------------
# Function : build_graphviz_model - Build Graphviz model text
#-------------------------------------------------------------------------------
sub build_graphviz_model{
    my $txt = shift;
    my $model =qq(digraph G {
        labelloc=t
        fontname=calibri
        fontsize=40
        fontcolor=red
        $txt}
    );
    return $model;
}

#-------------------------------------------------------------------------------
# Function : generate_graphviz - Invoke the dot command to generate the SVG image
#-------------------------------------------------------------------------------
sub generate_graphviz{
    my $txt = shift;
    my $result = `echo '$txt' | dot -Tsvg`;
    return $result;
}

sub main{

    # Create a database connection
    my $rdbms = new Enmac::RDBMS(user_name => "ENMAC");

    # Create a new CGI object
    my $cgi = CGI->new;

    # Get the selected values from the query parameters
    my $selected_comp_class = $cgi->param('ccd') || "";
    my $selected_menu = $cgi->param('menu') || "";
    my $from_state = $cgi->param('fromState') || "";
    my $to_state = $cgi->param('toState') || "";

    # Get life cycle and appearance to display in html page
    my $lic_and_aad_txt = fetch_lic_and_aad_from_ccd($rdbms, $selected_comp_class);
    
    # Get component classes for html drop down list
    my @comp_classes = fetch_component_class_defn($rdbms);
    my $comp_classes_html_txt = convert_arrayref_to_html_selection(\@comp_classes, $selected_comp_class);

    # Get menus for html drop down list
    my @menus = fetch_menu_items($rdbms);
    my $menus_html_txt = convert_arrayref_to_html_selection(\@menus, $selected_menu);

    # Create life cycle diagram
    my $lic_graphviz = $selected_comp_class ? build_graphviz_model(fetch_lic_for_graphviz($rdbms, $selected_comp_class, $selected_menu, $from_state, $to_state )) : '';
    my $lic_svg = generate_graphviz($lic_graphviz);

    # Render html output
    render_html($cgi, $comp_classes_html_txt, $menus_html_txt, $lic_svg, $from_state, $to_state, $lic_and_aad_txt);

}

main();

