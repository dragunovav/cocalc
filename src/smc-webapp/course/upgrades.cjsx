###
Upgrading quotas for all student projects
###
misc = require('smc-util/misc')

schema = require('smc-util/schema')

{React, rclass, rtypes, ReactDOM}  = require('../smc-react')

{Icon, Loading, NoUpgrades, Tip, UPGRADE_ERROR_STYLE} = require('../r_misc')

{Alert, Button, ButtonToolbar, Checkbox,
 FormGroup, FormControl, Panel, Row, Col} = require('react-bootstrap')


exports.StudentProjectUpgrades = rclass
    getDefaultProps: ->
        name  : rtypes.string.isRequired
        redux : rtypes.object.isRequired

    getInitialState: ->
        upgrade_quotas : false
        upgrades       : undefined

    save_upgrade_quotas: ->
        num_projects = @_num_projects
        upgrades = {}
        for quota, val of @state.upgrades
            val = misc.parse_number_input(val, round_number=false)
            if val*num_projects != @_your_upgrades[quota]
                display_factor = schema.PROJECT_UPGRADES.params[quota].display_factor
                upgrades[quota] = val / display_factor
        @setState(upgrade_quotas: false)
        if misc.len(upgrades) > 0
            @actions(@props.name).upgrade_all_student_projects(upgrades)

    upgrade_quotas_submittable: ->
        if @_upgrade_is_invalid
            return false
        num_projects = @_num_projects
        for quota, val of @state.upgrades
            val = misc.parse_number_input(val, round_number=false)
            if val*num_projects != (@_your_upgrades[quota] ? 0)
                changed = true
        return changed

    render_upgrade_heading: (num_projects) ->
        <Row key="heading">
            <Col md=5>
                <b style={fontSize:'11pt'}>Quota</b>
            </Col>
            {# <Col md=2><b style={fontSize:'11pt'}>Current upgrades</b></Col> }
            <Col md=7>
                <b style={fontSize:'11pt'}>Distribute upgrades equally to {num_projects} student {misc.plural(num_projects, 'project')} (amounts may be fractional)</b>
            </Col>
        </Row>

    is_upgrade_input_valid: (val, limit) ->
        parsed_val = misc.parse_number_input(val, round_number=false)
        if not parsed_val? or parsed_val > Math.max(0, limit)  # val=0 is always valid
            return false
        else
            return true

    render_upgrade_row_input: (quota, input_type, current, yours, num_projects, limit) ->
        ref = "upgrade_#{quota}"
        if input_type == 'number'
            val = @state.upgrades[quota] ? (yours / num_projects)
            if not @state.upgrades[quota]?
                if val is 0 and yours isnt 0
                    val = yours / num_projects

            if not @is_upgrade_input_valid(val, limit)
                bs_style = 'error'
                @_upgrade_is_invalid = true
                if misc.parse_number_input(val)?
                    label = <div style=UPGRADE_ERROR_STYLE>Reduce the above: you do not have enough upgrades</div>
                else
                    label = <div style=UPGRADE_ERROR_STYLE>Please enter a number</div>
            else
                label = <span></span>
            <FormGroup>
                <FormControl
                    type       = 'text'
                    ref        = {ref}
                    value      = {val}
                    bsStyle    = {bs_style}
                    onChange   = {=>u=@state.upgrades; u[quota] = ReactDOM.findDOMNode(@refs[ref]).value; @setState(upgrades:u)}
                />
                {label}
            </FormGroup>
        else if input_type == 'checkbox'
            val = @state.upgrades[quota] ? (if yours > 0 then 1 else 0)
            is_valid = @is_upgrade_input_valid(val, limit)
            if not is_valid
                @_upgrade_is_invalid = true
                label = <div style=UPGRADE_ERROR_STYLE>Uncheck this: you do not have enough upgrades</div>
            else
                label = if val == 0 then 'Enable' else 'Enabled'
            <form>
                <Checkbox
                    ref      = {ref}
                    checked  = {val > 0}
                    onChange = {(e)=>u=@state.upgrades; u[quota] = (if e.target.checked then 1 else 0); @setState(upgrades:u)}
                    />
                {label}
            </form>
        else
            console.warn('Invalid input type in render_upgrade_row_input: ', input_type)
            return

    render_upgrade_row: (quota, available, current, yours, num_projects) ->
        # quota -- name of the quota
        # available -- How much of this quota the user has available to use on the student projects.
        #              This is the total amount the user purchased minus the amount allocated to other
        #              projects that aren't projects in this course.
        # current   -- Sum of total upgrades currently allocated by anybody to the course projects
        # yours     -- How much of this quota this user has allocated to this quota total.
        # num_projects -- How many student projects there are.
        {display, desc, display_factor, display_unit, input_type} = schema.PROJECT_UPGRADES.params[quota]

        yours   *= display_factor
        current *= display_factor

        x = @state.upgrades[quota]
        input = if x == '' then 0 else misc.parse_number_input(x) ? (yours/num_projects) # currently typed in
        if input_type == 'checkbox'
            input = if input > 0 then 1 else 0

        ##console.log(quota, "remaining = (#{available} - #{input}/#{display_factor}*#{num_projects}) * #{display_factor}")

        remaining = misc.round2( (available - input/display_factor*num_projects) * display_factor )
        limit     = (available / num_projects) * display_factor

        cur = misc.round2(current / num_projects)
        if input_type == 'checkbox'
            if cur > 0 and cur < 1
                cur = "#{misc.round2(cur*100)}%"
            else if cur == 0
                cur = 'none'
            else
                cur = 'all'

        <Row key={quota}>
            <Col md=5>
                <Tip title={display} tip={desc}>
                    <strong>{display}</strong>
                </Tip>
                <span style={marginLeft:'1ex'}>({remaining} {misc.plural(remaining, display_unit)} remaining)</span>
            </Col>
            {# <Col md=2  style={marginTop: '8px'}>{cur}</Col> }
            <Col md=5>
                {@render_upgrade_row_input(quota, input_type, current, yours, num_projects, limit)}
            </Col>
            <Col md=2 style={marginTop: '8px'}>
                &times; {num_projects}
            </Col>
        </Row>

    render_upgrade_rows: (purchased_upgrades, applied_upgrades, num_projects, total_upgrades, your_upgrades) ->
        # purchased_upgrades - how much of each quota this user has purchased
        # applied_upgrades   - how much of each quota user has already applied to projects total
        # num_projects       - number of student projects
        # total_upgrades     - the total amount of each quota that has been applied (by anybody) to these student projects
        # your_upgrades      - total amount of each quota that this user has applied to these student projects
        @_upgrade_is_invalid = false  # will get set to true by render_upgrade_row if invalid.
        for quota in schema.PROJECT_UPGRADES.field_order
            total     = purchased_upgrades[quota]
            yours     = your_upgrades[quota] ? 0
            available = total - (applied_upgrades[quota] ? 0) + yours
            current   = total_upgrades[quota] ? 0
            @render_upgrade_row(quota, available, current, yours, num_projects)

    render_upgrade_quotas: ->
        redux = @props.redux

        # Get available upgrades that instructor has to apply
        account_store = redux.getStore('account')
        if not account_store?
            return <Loading/>

        purchased_upgrades = account_store.get_total_upgrades()
        if misc.is_zero_map(purchased_upgrades)
            # user has no upgrades on their account
            return <NoUpgrades cancel={=>@setState(upgrade_quotas:false)} />

        course_store = redux.getStore(@props.name)
        if not course_store?
            return <Loading/>

        # Get non-deleted student projects
        project_ids = course_store.get_student_project_ids()
        if not project_ids
            return <Loading/>
        num_projects = project_ids.length
        if not num_projects
            return <span>There are no student projects yet.<br/><br/>{@render_upgrade_submit_buttons()}</span>

        # Get remaining upgrades
        projects_store = redux.getStore('projects')
        if not projects_store?
            return <Loading/>
        applied_upgrades = projects_store.get_total_upgrades_you_have_applied()

        # Sum total amount of each quota that we have applied to all student projects
        total_upgrades = {}  # all upgrades by anybody
        your_upgrades  = {}  # just by you
        account_id = account_store.get_account_id()
        for project_id in project_ids
            your_upgrades  = misc.map_sum(your_upgrades, projects_store.get_upgrades_you_applied_to_project(project_id))
            total_upgrades = misc.map_sum(total_upgrades, projects_store.get_total_project_upgrades(project_id))
        # save for when we do the save
        @_your_upgrades = your_upgrades
        @_num_projects = num_projects

        <Alert bsStyle='warning'>
            <h3><Icon name='arrow-circle-up' /> Adjust your contributions to the student project quotas</h3>
            <hr/>
            {@render_upgrade_heading(num_projects)}
            <hr/>
            {@render_upgrade_rows(purchased_upgrades, applied_upgrades, num_projects, total_upgrades, your_upgrades)}
            {@render_upgrade_submit_buttons()}
            {@render_admin_upgrade() if redux.getStore('account').get('groups')?.contains('admin')}
        </Alert>

    save_admin_upgrade: (e) ->
        e.preventDefault()
        s = ReactDOM.findDOMNode(@refs.admin_input).value
        quotas = JSON.parse(s)
        console.log("admin upgrade '#{s}' -->", quotas)
        @actions(@props.name).admin_upgrade_all_student_projects(quotas)
        return false

    render_admin_upgrade: ->
        <div>
            <br/>
            <hr/>
            <h3>Admin Upgrade</h3>
            Enter a Javascript-parseable object and hit enter (see the Javascript console for feedback):
            <form onSubmit={@save_admin_upgrade}>
                <FormGroup>
                    <FormControl
                        ref         = 'admin_input'
                        type        = 'text'
                        placeholder = {JSON.stringify(schema.DEFAULT_QUOTAS)}
                    />
                </FormGroup>
            </form>
        </div>

    render_upgrade_submit_buttons: ->
        <ButtonToolbar>
            <Button
                bsStyle  = 'primary'
                onClick  = {@save_upgrade_quotas}
                disabled = {not @upgrade_quotas_submittable()}
            >
                <Icon name='arrow-circle-up' /> Submit changes
            </Button>
            <Button onClick={=>@setState(upgrade_quotas:false)}>
                Cancel
            </Button>
        </ButtonToolbar>

    adjust_quotas: ->
        @setState(upgrade_quotas:true, upgrades:{})

    render_upgrade_quotas_button: ->
        <Button bsStyle='primary' onClick={@adjust_quotas}>
            <Icon name='arrow-circle-up' /> Adjust quotas...
        </Button>

    render: ->
        <Panel header={<h4><Icon name='dashboard' />  Upgrade all student projects (you pay)</h4>}>
            {if @state.upgrade_quotas then @render_upgrade_quotas() else @render_upgrade_quotas_button()}
            <hr/>
            <div style={color:"#666"}>
                <p>Add or remove upgrades to student projects associated to this course, augmenting what is provided for free and what students may have purchased.</p>
            </div>
        </Panel>
