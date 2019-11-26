import React, { Component } from 'react'

export class NewScreen extends Component {
  constructor(props) {
    super(props);

    this.state = {
      groupName: '',
      invites: '',
      color: ''
    }

    this.groupNameChange = this.groupNameChange.bind(this);
    this.invChange = this.invChange.bind(this);
    this.colorChange = this.colorChange.bind(this);
  }

  groupNameChange(event) {
    this.setState({
      groupName: event.target.value
    });
  }

  invChange(event) {
    this.setState({
      invites: event.target.value
    });
  }

  colorChange(event) {
    this.setState({
      color: event.target.value
    });
  }

  render() {
    return (
      <div className="h-100 w-100 flex flex-column">
        <div className="w-100 w-50-l w-50-xl">
          <h2 className="f8 pl3 pt4">Create New Group</h2>
          <h2 className="f8 pl3 pt6">Group Name</h2>
          <p className="f9 pl3 gray2 lh-copy">Alphanumeric characters only</p>
          <textarea
            className="f7 ba b--gray3 w-100 pa3 ml3 mt2"
            rows={1}
            placeholder="example-chat-name"
            style={{
              resize: "none",
              height: 48
            }}
          />
          <h2 className="f8 pl3 pt6">Group Avatar</h2>
          <p className="f9 pl3 gray2 lh-copy">
            Select a color to represent your group
          </p>
          <textarea
            className="f7 ba b--gray3 w-50 w-25-xl pa3 ml3 mt2"
            rows={1}
            placeholder="#000000"
            style={{
              resize: "none",
              height: 48
            }}
          />
          <h2 className="f8 pl3 pt6">Add Group Members</h2>
          <p className="f9 pl3 gray2 lh-copy">
            Search for ships to invite to your group
          </p>
          <textarea
            className="f7 ba b--gray3 w-100 pa3 pl5 ml3 mt2 mb7"
            rows={1}
            placeholder="Search for ships..."
            style={{
              resize: "none",
              height: 48
            }}
          />
          <button
          className="ml3 f8 ba pa2 b--green2 green2">Start Group</button>
          <button className="f8 ml3 ba pa2 b--black">Cancel</button>
        </div>
      </div>
    );
  }
}

export default NewScreen
