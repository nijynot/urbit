import React, { Component } from 'react'
import moment from 'moment';


export class LinkItem extends Component {
  constructor(props) {
    super(props);
    this.state = {
      timeSinceLinkPost: this.getTimeSinceLinkPost()
    };
  }

  componentDidMount() {
    this.updateTimeSinceNewestMessageInterval = setInterval( () => {
      this.setState({timeSinceLinkPost: this.getTimeSinceLinkPost()});
    }, 60000);
  }

  componentWillUnmount() {
    if (this.updateTimeSinceNewestMessageInterval) {
      clearInterval(this.updateTimeSinceNewestMessageInterval);
      this.updateTimeSinceNewestMessageInterval = null;
    }
  }

  getTimeSinceLinkPost() {
    return !!this.props.timestamp ?
      moment.unix(this.props.timestamp / 1000).from(moment.utc())
      : '';
  }

  render() {

    let props = this.props;

    let mono = (props.mono) ? "mono" : "inter";

    let URLparser = new RegExp(/((?:([\w\d\.-]+)\:\/\/?){1}(?:(www)\.?){0,1}(((?:[\w\d-]+\.)*)([\w\d-]+\.[\w\d]+))){1}(?:\:(\d+)){0,1}((\/(?:(?:[^\/\s\?]+\/)*))(?:([^\?\/\s#]+?(?:.[^\?\s]+){0,1}){0,1}(?:\?([^\s#]+)){0,1})){0,1}(?:#([^#\s]+)){0,1}/);

    let hostname = URLparser.exec(props.url);

    if (hostname) {
      hostname = hostname[4];
    }

    return (
      <div className="w-100 lh-copy pv6">
        <a href={props.url}
        className="w-100 flex">
          <p className="f8 truncate">{props.title}
            <span className="gray2 ml2 flex-shrink-0">{hostname} ↗</span>
          </p>
        </a>
        <div className="w-100">
          <span className={"f9 pr2 " + mono}>{props.ship}</span>
        <span className="f9 inter gray2">{this.state.timeSinceLinkPost}</span>
        </div>
      </div>
    )
  }
}

export default LinkItem
